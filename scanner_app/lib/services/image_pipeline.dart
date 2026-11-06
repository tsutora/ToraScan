import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/crop_quad.dart';
import '../models/scan_preset.dart';

/// Pure image processing for scanned pages.
///
/// No Flutter imports, so this runs in an isolate, in a plain Dart VM (see
/// `tool/preview.dart`) and in unit tests without a widget binding.
///
/// The pipeline mirrors what a flatbed scanner does, in this order:
///
///  1. estimate the scene lighting and divide it out (shadow removal)
///  2. neutralise the colour of the light source (white balance)
///  3. anchor paper at white and pull ink down to black (contrast)
///  4. restore a little acutance (unsharp mask)
///
/// Every tonal operation is a single scalar gain on a pixel, or a curve driven
/// by its luminance. Scaling R, G and B by the same number keeps the ratio
/// between the channels â€” and therefore the hue â€” intact, so a pink form stays
/// pink and black ink stays black. Chroma is only touched where the *local
/// background* is a plausible light cast (roughly neutral, and warm or cool
/// rather than magenta or green).
///
/// All heavy passes address the image as a byte buffer. The `image` package's
/// `Pixel` objects are convenient but allocate one object per pixel, which is
/// what made a filter take ten seconds on a mid-range phone.
class ImagePipeline {
  const ImagePipeline._();

  /// Documents do not need 12 MP. Capping keeps processing around a second
  /// per page while still printing cleanly at A4.
  static const int maxDimension = 2400;
  static const int jpegQuality = 88;

  static Uint8List processPreset(
    Uint8List bytes,
    ScanPreset preset, {
    CropQuad? crop,
    int maxEdge = maxDimension,
    int quality = jpegQuality,
  }) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image data');
    }

    img.Image image = img.bakeOrientation(decoded);

    final int longest = image.width > image.height ? image.width : image.height;
    if (longest > maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: maxEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: maxEdge,
              interpolation: img.Interpolation.average,
            );
    }

    // Rectify first: the crop defines which part of the page exists, and the
    // enhancement then works on exactly that region. A quarter-turn is baked
    // in here too, because the crop was drawn on the turned page.
    if (crop != null) {
      if (crop.quarterTurns != 0) {
        image = img.copyRotate(image, angle: crop.quarterTurns * 90);
      }
      if (!crop.isFull) {
        image = cropPerspective(image, crop);
      }
    }

    final img.Image result = switch (preset) {
      ScanPreset.none => image,
      ScanPreset.auto => auto(image),
      ScanPreset.lighten => lighten(image),
      ScanPreset.grayscale => gray(image),
      ScanPreset.blackWhite => blackWhite(image),
    };

    return img.encodeJpg(result, quality: quality);
  }

  // ---------------------------------------------------------------- presets

  /// The "magic" preset: even lighting, neutral paper, deep ink, colours kept.
  ///
  /// Chroma is expanded by 1.5x, which is what CamScanner's own colour pass
  /// does: for each pixel it computes `Y` with BT.601 weights and maps every
  /// channel to `clamp(Y + 1.5 * (C - Y))`. Scaling all three channels around
  /// the same luminance leaves the hue untouched (pink stays pink, only more
  /// so) while making printed colour blocks look as saturated as they did on
  /// paper. The expansion backs off per pixel when a channel would clip, so it
  /// cannot wash a bright block out to white.
  static img.Image auto(img.Image src) {
    img.Image out = flattenIllumination(src);
    out = toneMap(out, whitePoint: 236, saturation: 1.5);
    return sharpen(out, asymmetric: true);
  }

  /// For dark captures and grey paper: like [auto], biased brighter.
  static img.Image lighten(img.Image src) {
    img.Image out = flattenIllumination(src);
    out = toneMap(out, whitePoint: 246, inkPercentile: 3, brightness: 1.04);
    return sharpen(out, amount: 0.3);
  }

  static img.Image gray(img.Image src) {
    img.Image out = flattenIllumination(src);
    out = toneMap(out, whitePoint: 236);
    return _toGray(out);
  }

  /// Local adaptive threshold (Sauvola-style), which keeps text legible on
  /// unevenly lit pages where a global threshold turns whole regions black.
  static img.Image blackWhite(img.Image src) {
    final img.Image flattened = flattenIllumination(src);
    final img.Image source = _toRgb8(flattened);
    final int w = source.width;
    final int h = source.height;
    final Uint8List bytes = source.toUint8List();
    final int stride = source.rowStride;

    // Luma plane, used for both the integral image and the decision.
    final Uint8List luma = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int outRow = y * w;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        luma[outRow + x] =
            (bytes[i] * 299 + bytes[i + 1] * 587 + bytes[i + 2] * 114) ~/ 1000;
      }
    }

    const int window = 31;
    const double k = 0.18;
    final int integralStride = w + 1;

    // Summed-area table for O(1) window means.
    final Uint32List integral = Uint32List(integralStride * (h + 1));
    for (int y = 0; y < h; y++) {
      int rowSum = 0;
      final int row = y * w;
      for (int x = 0; x < w; x++) {
        rowSum += luma[row + x];
        integral[(y + 1) * integralStride + (x + 1)] =
            integral[y * integralStride + (x + 1)] + rowSum;
      }
    }

    final Uint8List out = Uint8List(w * h * 3);
    final int radius = window ~/ 2;

    for (int y = 0; y < h; y++) {
      final int y1 = y - radius < 0 ? 0 : y - radius;
      final int y2 = y + radius >= h ? h - 1 : y + radius;
      final int outRow = y * w;
      for (int x = 0; x < w; x++) {
        final int x1 = x - radius < 0 ? 0 : x - radius;
        final int x2 = x + radius >= w ? w - 1 : x + radius;

        final int area = (x2 - x1 + 1) * (y2 - y1 + 1);
        final int sum =
            integral[(y2 + 1) * integralStride + (x2 + 1)] -
            integral[y1 * integralStride + (x2 + 1)] -
            integral[(y2 + 1) * integralStride + x1] +
            integral[y1 * integralStride + x1];
        final double mean = sum / area;

        final int value = luma[outRow + x] > mean * (1 - k) ? 255 : 0;
        final int dest = (outRow + x) * 3;
        out[dest] = value;
        out[dest + 1] = value;
        out[dest + 2] = value;
      }
    }

    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: out.buffer,
      numChannels: 3,
    );
  }

  // ------------------------------------------------------------------ crop

  /// Rectifies [quad] out of [src] into an upright rectangle.
  ///
  /// This is a real perspective transform (a homography), not a bounding-box
  /// crop, so a page whose corners were dragged out of square still comes back
  /// with parallel edges and right angles. The output size follows the quad's
  /// average edge lengths, which preserves the page's aspect ratio.
  ///
  /// Both buffers are addressed as raw bytes rather than through `getPixel`,
  /// because a 4 MP warp is ~17 M pixel reads and object allocation would make
  /// that visibly slow.
  static img.Image cropPerspective(img.Image src, CropQuad quad) {
    if (quad.isFull) {
      return src;
    }

    final double sw = src.width.toDouble();
    final double sh = src.height.toDouble();

    // Quad corners in source pixel coordinates.
    final double x0 = quad.tlX * sw;
    final double y0 = quad.tlY * sh;
    final double x1 = quad.trX * sw;
    final double y1 = quad.trY * sh;
    final double x2 = quad.brX * sw;
    final double y2 = quad.brY * sh;
    final double x3 = quad.blX * sw;
    final double y3 = quad.blY * sh;

    final double top = _length(x0, y0, x1, y1);
    final double bottom = _length(x3, y3, x2, y2);
    final double left = _length(x0, y0, x3, y3);
    final double right = _length(x1, y1, x2, y2);

    final int outW = ((top + bottom) / 2).round().clamp(1, maxDimension);
    final int outH = ((left + right) / 2).round().clamp(1, maxDimension);

    // Homography mapping the unit square onto the quad (Heckbert's method).
    final double dx1 = x1 - x2;
    final double dx2 = x3 - x2;
    final double dx3 = x0 - x1 + x2 - x3;
    final double dy1 = y1 - y2;
    final double dy2 = y3 - y2;
    final double dy3 = y0 - y1 + y2 - y3;

    final double den = dx1 * dy2 - dx2 * dy1;
    final bool affine = dx3.abs() < 1e-9 && dy3.abs() < 1e-9;

    double a = x1 - x0;
    double b = x3 - x0;
    double c = x0;
    double d = y1 - y0;
    double e = y3 - y0;
    double f = y0;
    double g = 0;
    double h = 0;

    if (!affine && den.abs() > 1e-12) {
      g = (dx3 * dy2 - dx2 * dy3) / den;
      h = (dx1 * dy3 - dx3 * dy1) / den;
      a = x1 - x0 + g * x1;
      b = x3 - x0 + h * x3;
      d = y1 - y0 + g * y1;
      e = y3 - y0 + h * y3;
    }

    final img.Image source = _toRgb8(src);

    final Uint8List sourceBytes = source.toUint8List();
    final int sourceStride = source.rowStride;
    final int sourceW = source.width;
    final int sourceH = source.height;

    final Uint8List out = Uint8List(outW * outH * 3);

    for (int py = 0; py < outH; py++) {
      final double v = (py + 0.5) / outH;
      for (int px = 0; px < outW; px++) {
        final double u = (px + 0.5) / outW;

        final double w = g * u + h * v + 1;
        final double fx = (a * u + b * v + c) / w - 0.5;
        final double fy = (d * u + e * v + f) / w - 0.5;

        final double cx = fx.clamp(0.0, (sourceW - 1).toDouble());
        final double cy = fy.clamp(0.0, (sourceH - 1).toDouble());

        final int x0i = cx.floor();
        final int y0i = cy.floor();
        final int x1i = x0i + 1 >= sourceW ? sourceW - 1 : x0i + 1;
        final int y1i = y0i + 1 >= sourceH ? sourceH - 1 : y0i + 1;
        final double tx = cx - x0i;
        final double ty = cy - y0i;

        final int rowTop = y0i * sourceStride;
        final int rowBottom = y1i * sourceStride;
        final int colLeft = x0i * 3;
        final int colRight = x1i * 3;

        final int i00 = rowTop + colLeft;
        final int i10 = rowTop + colRight;
        final int i01 = rowBottom + colLeft;
        final int i11 = rowBottom + colRight;

        final int dest = (py * outW + px) * 3;
        for (int ch = 0; ch < 3; ch++) {
          final double topValue =
              sourceBytes[i00 + ch] +
              (sourceBytes[i10 + ch] - sourceBytes[i00 + ch]) * tx;
          final double bottomValue =
              sourceBytes[i01 + ch] +
              (sourceBytes[i11 + ch] - sourceBytes[i01 + ch]) * tx;
          final double value = topValue + (bottomValue - topValue) * ty;
          out[dest + ch] = value.round().clamp(0, 255);
        }
      }
    }

    return img.Image.fromBytes(
      width: outW,
      height: outH,
      bytes: out.buffer,
      bytesOffset: out.offsetInBytes,
      numChannels: 3,
    );
  }

  static double _length(double x0, double y0, double x1, double y1) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ------------------------------------------------------------- primitives

  /// Removes the low-frequency brightness *and colour* of the scene (a shadow,
  /// a lamp on one side of the page) while keeping edges: each pixel is divided
  /// by a heavily downsampled estimate of its local paper colour.
  ///
  /// The estimate uses the *peak* of each cell, dilated across neighbours, so
  /// dense ink never drags the background down â€” that is what leaves white
  /// halos around text blocks in a naive implementation. The grid is coarse on
  /// purpose: a cell should almost always contain some paper, and a wider
  /// dilation (two cells) bridges a whole line of dense text.
  ///
  /// Only pixels that could plausibly be paper vote on the colour. A pixel
  /// whose middle channel is not between red and blue â€” pink, magenta, green â€”
  /// is pigment, not a light cast, and is left out of the estimate. That is
  /// what keeps a pink form pink instead of "correcting" it to grey.
  static img.Image flattenIllumination(img.Image src, {int scale = 16}) {
    final int w = src.width;
    final int h = src.height;
    if (w < scale * 2 || h < scale * 2) {
      return src;
    }

    final img.Image source = _toRgb8(src);
    final Uint8List bytes = source.toUint8List();
    final int stride = source.rowStride;

    final int sw = (w + scale - 1) ~/ scale;
    final int sh = (h + scale - 1) ~/ scale;
    final int cells = sw * sh;
    final Int32List peakR = Int32List(cells);
    final Int32List peakG = Int32List(cells);
    final Int32List peakB = Int32List(cells);
    final Int32List samples = Int32List(cells);
    int lumaSum = 0;
    int lumaCount = 0;

    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int cellRow = (y ~/ scale) * sw;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int r = bytes[i];
        final int g = bytes[i + 1];
        final int b = bytes[i + 2];
        lumaSum += r * 299 + g * 587 + b * 114;
        lumaCount++;

        final int index = cellRow + (x ~/ scale);
        samples[index]++;
        if (r > peakR[index]) {
          peakR[index] = r;
        }
        if (g > peakG[index]) {
          peakG[index] = g;
        }
        if (b > peakB[index]) {
          peakB[index] = b;
        }
      }
    }

    // Every cell has a peak: the brightest pixel wins, whatever its hue. That
    // is what makes a pink form contribute its own brightness to the estimate
    // while its colour is still protected by the neutrality test below. Only
    // the brightness is needed for the gain; the colour only decides how much
    // of the local cast may be neutralised.
    final int grey = lumaCount == 0 ? 200 : (lumaSum / lumaCount / 1000).round();
    final int fillR = grey;
    final int fillG = grey;
    final int fillB = grey;
    for (int i = 0; i < cells; i++) {
      if (samples[i] == 0) {
        peakR[i] = fillR;
        peakG[i] = fillG;
        peakB[i] = fillB;
      }
    }

    // A small dilation makes each estimate monotone across ink, then a blur
    // removes the blockiness of the downsampled grid.
    final Int32List bgR = _boxBlurInt(_dilateInt(peakR, sw, sh, 2), sw, sh, 2);
    final Int32List bgG = _boxBlurInt(_dilateInt(peakG, sw, sh, 2), sw, sh, 2);
    final Int32List bgB = _boxBlurInt(_dilateInt(peakB, sw, sh, 2), sw, sh, 2);

    int total = 0;
    int counted = 0;
    for (int i = 0; i < cells; i++) {
      final int luma = (bgR[i] * 299 + bgG[i] * 587 + bgB[i] * 114) ~/ 1000;
      if (luma > 1) {
        total += luma;
        counted++;
      }
    }
    final int meanBackground = counted == 0 ? 200 : total ~/ counted;

    // Paper should land near white, but never darken an already bright page.
    final int target = meanBackground < 215 ? 226 : meanBackground;

    final Uint8List out = Uint8List(w * h * 3);

    // The background grid is [scale] times coarser than the page, so a whole
    // block of pixels shares the same four cells. Resolving the column indices
    // once keeps the per-pixel loop down to the interpolation itself.
    final Int32List colLeft = Int32List(w);
    final Int32List colRight = Int32List(w);
    final Int32List colWeight = Int32List(w);
    for (int x = 0; x < w; x++) {
      final double cx = (x / scale - 0.5).clamp(0.0, sw - 1.0);
      final int x0 = cx.floor();
      colLeft[x] = x0;
      colRight[x] = (x0 + 1).clamp(0, sw - 1);
      colWeight[x] = ((cx - x0) * 256).round();
    }

    for (int y = 0; y < h; y++) {
      final double cy = (y / scale - 0.5).clamp(0.0, sh - 1.0);
      final int y0 = cy.floor();
      final int y1 = (y0 + 1).clamp(0, sh - 1);
      final int wy = ((cy - y0) * 256).round();
      final int rowTop = y0 * sw;
      final int rowBottom = y1 * sw;
      final int row = y * stride;
      final int outRow = y * w * 3;

      for (int x = 0; x < w; x++) {
        final int x0 = colLeft[x];
        final int x1 = colRight[x];
        final int wx = colWeight[x];
        final int invX = 256 - wx;
        final int invY = 256 - wy;

        final int bgRHere =
            ((bgR[rowTop + x0] * invX + bgR[rowTop + x1] * wx) * invY +
                (bgR[rowBottom + x0] * invX + bgR[rowBottom + x1] * wx) * wy) >>
            16;
        final int bgGHere =
            ((bgG[rowTop + x0] * invX + bgG[rowTop + x1] * wx) * invY +
                (bgG[rowBottom + x0] * invX + bgG[rowBottom + x1] * wx) * wy) >>
            16;
        final int bgBHere =
            ((bgB[rowTop + x0] * invX + bgB[rowTop + x1] * wx) * invY +
                (bgB[rowBottom + x0] * invX + bgB[rowBottom + x1] * wx) * wy) >>
            16;

        final int red = bgRHere.clamp(24, 255);
        final int green = bgGHere.clamp(24, 255);
        final int blue = bgBHere.clamp(24, 255);

        final int bgLuma = (red * 299 + green * 587 + blue * 114) ~/ 1000;
        final double factor = (target / bgLuma).clamp(0.55, 2.8);

        // How much of the local colour is light rather than pigment. Paper is
        // near-neutral (whatever the lamp does to it), a printed block is not.
        final int hi = math.max(red, math.max(green, blue));
        final int lo = math.min(red, math.min(green, blue));
        final int saturation = hi <= 1 ? 0 : (hi - lo) * 100 ~/ hi;
        double neutral = ((60 - saturation) / 22).clamp(0.0, 1.0);
        // Magenta / pink / green backgrounds are content, not a cast.
        if ((red - green) * (blue - green) > 0) {
          neutral = 0;
        }

        // Luma-preserving gains that pull the local background to neutral.
        final double gainR = 1 + (bgLuma / red - 1) * neutral;
        final double gainG = 1 + (bgLuma / green - 1) * neutral;
        final double gainB = 1 + (bgLuma / blue - 1) * neutral;

        final int i = row + x * 3;
        final int dest = outRow + x * 3;
        out[dest] = (bytes[i] * factor * gainR).round().clamp(0, 255);
        out[dest + 1] = (bytes[i + 1] * factor * gainG).round().clamp(0, 255);
        out[dest + 2] = (bytes[i + 2] * factor * gainB).round().clamp(0, 255);
      }
    }

    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: out.buffer,
      numChannels: 3,
    );
  }

  /// Grey-world white balance and the ink anchor, composed into one pass.
  ///
  /// White balance is deliberately conservative: it only averages pixels that
  /// look like light or paper (warm/cool, low saturation), and gains are
  /// clamped. A page that is *mostly* pink has its white margins to anchor
  /// against; the pink itself is not allowed to vote, so it survives.
  ///
  /// The tonal stretch is applied as one multiplier per pixel rather than one
  /// per channel. The multiplier is also capped so the brightest channel never
  /// leaves 255 â€” a pink that is already near the top of the range brightens
  /// only until it would clip, instead of washing out to white.
  static img.Image toneMap(
    img.Image src, {
    double whitePoint = 236,
    double inkPercentile = 1,
    double strength = 0.4,
    double brightness = 1,
    double saturation = 1,
  }) {
    final int pixels = src.width * src.height;
    if (pixels == 0) {
      return src;
    }

    final img.Image source = _toRgb8(src);
    final int w = source.width;
    final int h = source.height;
    final Uint8List bytes = source.toUint8List();
    final int stride = source.rowStride;

    // Sampling every fourth pixel is plenty for a grey-world average, and it
    // keeps this statistics pass at a quarter of the cost.
    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    int neutralCount = 0;
    final int sampleStep = 4;
    for (int y = 0; y < h; y += sampleStep) {
      final int row = y * stride;
      for (int x = 0; x < w; x += sampleStep) {
        final int i = row + x * 3;
        final int r = bytes[i];
        final int g = bytes[i + 1];
        final int b = bytes[i + 2];
        final int hi = math.max(r, math.max(g, b));
        final int lo = math.min(r, math.min(g, b));
        final int saturation = hi <= 0 ? 0 : (hi - lo) * 100 ~/ hi;
        if (saturation > 24 || (r - g) * (b - g) > 0) {
          continue;
        }
        sumR += r;
        sumG += g;
        sumB += b;
        neutralCount++;
      }
    }

    double gainR = 1;
    double gainG = 1;
    double gainB = 1;
    final int sampled = ((w + sampleStep - 1) ~/ sampleStep) *
        ((h + sampleStep - 1) ~/ sampleStep);
    if (neutralCount * 8 >= sampled && neutralCount > 0) {
      final double meanR = sumR / neutralCount;
      final double meanG = sumG / neutralCount;
      final double meanB = sumB / neutralCount;
      final double target = (meanR + meanG + meanB) / 3;
      gainR = _balance(target, meanR, strength);
      gainG = _balance(target, meanG, strength);
      gainB = _balance(target, meanB, strength);
    }

    final Int32List gainTableR = Int32List(256);
    final Int32List gainTableG = Int32List(256);
    final Int32List gainTableB = Int32List(256);
    for (int i = 0; i < 256; i++) {
      gainTableR[i] = (i * gainR).round().clamp(0, 255);
      gainTableG[i] = (i * gainG).round().clamp(0, 255);
      gainTableB[i] = (i * gainB).round().clamp(0, 255);
    }

    // Histogram of the white-balanced page, and a second one restricted to
    // paper-like pixels: a pink page must take its white point from its white
    // margins, not from the pink.
    final Int32List histogram = Int32List(256);
    final Int32List paperHistogram = Int32List(256);
    int paperCount = 0;
    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int r = bytes[i];
        final int g = bytes[i + 1];
        final int b = bytes[i + 2];
        final int br = gainTableR[r];
        final int bg = gainTableG[g];
        final int bb = gainTableB[b];
        final int luma = (br * 299 + bg * 587 + bb * 114) ~/ 1000;
        histogram[luma]++;

        final int hi = math.max(r, math.max(g, b));
        final int lo = math.min(r, math.min(g, b));
        final int saturation = hi <= 0 ? 0 : (hi - lo) * 100 ~/ hi;
        if (saturation <= 28 && (r - g) * (b - g) <= 0) {
          paperHistogram[luma]++;
          paperCount++;
        }
      }
    }

    final int black = _percentile(histogram, pixels, inkPercentile);
    int paper = _percentile(
      paperCount * 6 >= pixels ? paperHistogram : histogram,
      paperCount * 6 >= pixels ? paperCount : pixels,
      55,
    );

    // A blank page has no ink to anchor to; brightening it would only blow out
    // the paper, so it keeps the white balance alone.
    final double white = paper >= 120 && paper <= 252 ? paper.toDouble() : whitePoint;
    final bool anchor = black <= white * 0.62;
    final double scale = anchor
        ? (255 / (white - black) * brightness).clamp(0.85, 2.6)
        : 1.0;

    final Uint8List out = Uint8List(w * h * 3);
    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int outRow = y * w * 3;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int dest = outRow + x * 3;
        final int r = gainTableR[bytes[i]];
        final int g = gainTableG[bytes[i + 1]];
        final int b = gainTableB[bytes[i + 2]];

        final int luma = (r * 299 + g * 587 + b * 114) ~/ 1000;
        final int mapped = ((luma - black) * scale).round().clamp(0, 255);
        // Without ink there is no interval to stretch: `mapped` would be zero
        // for the whole page and turn blank paper black. Leave those pixels at
        // their white-balanced value instead.
        double multiplier = !anchor || luma <= 0 ? 1.0 : mapped / luma;

        // Keep the hue: never scale past the point where the brightest channel
        // clips. Bright pigment then simply keeps its colour.
        final int maxChannel = math.max(r, math.max(g, b));
        if (maxChannel > 0) {
          final double cap = 255 / maxChannel;
          if (multiplier > cap) {
            multiplier = cap;
          }
        }

        int red = (r * multiplier).round().clamp(0, 255);
        int green = (g * multiplier).round().clamp(0, 255);
        int blue = (b * multiplier).round().clamp(0, 255);

        if (saturation != 1) {
          // Expand chroma around the pixel's own luminance. The factor is the
          // requested one unless a channel would leave [0, 255]; in that case
          // it is reduced for this pixel so the hue cannot shift. Reducing
          // rather than clipping is what keeps a bright red block red instead
          // of turning its highlights white.
          final double luma = (red * 299 + green * 587 + blue * 114) / 1000;
          int up = 0;
          int down = 0;
          final int dr = red - luma.round();
          final int dg = green - luma.round();
          final int db = blue - luma.round();
          final int peak = math.max(dr, math.max(dg, db));
          final int trough = math.min(dr, math.min(dg, db));
          if (peak > up) {
            up = peak;
          }
          if (-trough > down) {
            down = -trough;
          }

          double factor = saturation;
          final int lumaRound = luma.round();
          if (up > 0) {
            final double room = (255 - lumaRound) / up;
            if (room < factor) {
              factor = room;
            }
          }
          if (down > 0) {
            final double room = lumaRound / down;
            if (room < factor) {
              factor = room;
            }
          }
          if (factor < 1) {
            factor = 1;
          }
          if (factor > 1) {
            red = (lumaRound + (red - lumaRound) * factor).round().clamp(0, 255);
            green =
                (lumaRound + (green - lumaRound) * factor).round().clamp(0, 255);
            blue =
                (lumaRound + (blue - lumaRound) * factor).round().clamp(0, 255);
          }
        }

        out[dest] = red;
        out[dest + 1] = green;
        out[dest + 2] = blue;
      }
    }

    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: out.buffer,
      numChannels: 3,
    );
  }

  /// Grey-world assumption: pull the average colour towards neutral. Strength
  /// is deliberately partial so a deliberately coloured document survives.
  static img.Image whiteBalance(img.Image src, {double strength = 0.4}) {
    final img.Image source = _toRgb8(src);
    final int w = source.width;
    final int h = source.height;
    final Uint8List bytes = source.toUint8List();
    final int stride = source.rowStride;

    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    int samples = 0;

    for (int y = 0; y < h; y += 2) {
      final int row = y * stride;
      for (int x = 0; x < w; x += 2) {
        final int i = row + x * 3;
        final int r = bytes[i];
        final int g = bytes[i + 1];
        final int b = bytes[i + 2];
        final int hi = math.max(r, math.max(g, b));
        final int lo = math.min(r, math.min(g, b));
        final int saturation = hi <= 0 ? 0 : (hi - lo) * 100 ~/ hi;
        if (saturation > 24 || (r - g) * (b - g) > 0) {
          continue;
        }
        sumR += r;
        sumG += g;
        sumB += b;
        samples++;
      }
    }
    if (samples == 0) {
      return source;
    }

    final double meanR = sumR / samples;
    final double meanG = sumG / samples;
    final double meanB = sumB / samples;
    final double target = (meanR + meanG + meanB) / 3;

    final double gainR = _balance(target, meanR, strength);
    final double gainG = _balance(target, meanG, strength);
    final double gainB = _balance(target, meanB, strength);

    if (gainR == 1 && gainG == 1 && gainB == 1) {
      return source;
    }

    return _applyGains(source, gainR, gainG, gainB);
  }

  /// Anchors paper at white and maps real ink to black.
  ///
  /// Unlike a percentile stretch of the whole histogram, a blank page has no
  /// ink to find, and is left untouched instead of being crushed.
  static img.Image stretchInk(
    img.Image src, {
    double whitePoint = 236,
    double inkPercentile = 1,
  }) {
    return toneMap(
      src,
      whitePoint: whitePoint,
      inkPercentile: inkPercentile,
      strength: 0,
    );
  }

  /// Unsharp mask: adds back a fraction of the local detail removed by a
  /// small blur. Far less halo-prone than a fixed convolution kernel.
  ///
  /// A five-point blur is used instead of a separable Gaussian: it is one pass,
  /// integer-only, and visually indistinguishable at this radius.
  ///
  /// With [asymmetric] the detail is shaped the way CamScanner's own sharpener
  /// shapes it: a pixel *darker* than its neighbourhood by more than 20 levels
  /// keeps twice its detail, a difference between 10 and 20 levels is kept as
  /// is, and anything lighter than that is halved. Ink strokes therefore get
  /// darker without the white rim that a symmetric unsharp leaves on paper.
  static img.Image sharpen(
    img.Image src, {
    double amount = 0.45,
    bool asymmetric = false,
  }) {
    if (amount <= 0) {
      return src;
    }

    final img.Image source = _toRgb8(src);
    final int w = source.width;
    final int h = source.height;
    final Uint8List bytes = source.toUint8List();
    final int stride = source.rowStride;
    final Uint8List out = Uint8List(w * h * 3);
    final int amount256 = (amount * 256).round();

    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int rowUp = (y > 0 ? y - 1 : y) * stride;
      final int rowDown = (y < h - 1 ? y + 1 : y) * stride;
      final int outRow = y * w * 3;

      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int iLeft = row + (x > 0 ? x - 1 : x) * 3;
        final int iRight = row + (x < w - 1 ? x + 1 : x) * 3;
        final int iUp = rowUp + x * 3;
        final int iDown = rowDown + x * 3;
        final int dest = outRow + x * 3;

        for (int ch = 0; ch < 3; ch++) {
          final int centre = bytes[i + ch];
          final int soft =
              (bytes[iLeft + ch] +
                  bytes[iRight + ch] +
                  bytes[iUp + ch] +
                  bytes[iDown + ch] +
                  centre * 2) ~/
              6;
          int detail = centre - soft;
          if (asymmetric) {
            if (detail < -20) {
              detail *= 2;
            } else if (detail >= -10) {
              detail ~/= 2;
            }
          }
          final int value = centre + (detail * amount256 ~/ 256);
          out[dest + ch] = value.clamp(0, 255);
        }
      }
    }

    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: out.buffer,
      numChannels: 3,
    );
  }

  // ------------------------------------------------------------------ utils

  static img.Image _toRgb8(img.Image src) {
    if (src.format == img.Format.uint8 && src.numChannels == 3) {
      return src;
    }
    return src.convert(format: img.Format.uint8, numChannels: 3);
  }

  static img.Image _toGray(img.Image src) {
    final img.Image source = _toRgb8(src);
    final int w = source.width;
    final int h = source.height;
    final Uint8List bytes = source.toUint8List();
    final int stride = source.rowStride;
    final Uint8List out = Uint8List(w * h * 3);

    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int outRow = y * w * 3;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int value =
            (bytes[i] * 299 + bytes[i + 1] * 587 + bytes[i + 2] * 114) ~/ 1000;
        final int dest = outRow + x * 3;
        out[dest] = value;
        out[dest + 1] = value;
        out[dest + 2] = value;
      }
    }

    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: out.buffer,
      numChannels: 3,
    );
  }

  static img.Image _applyGains(
    img.Image src,
    double gainR,
    double gainG,
    double gainB,
  ) {
    final int w = src.width;
    final int h = src.height;
    final Uint8List bytes = src.toUint8List();
    final int stride = src.rowStride;
    final Uint8List out = Uint8List(w * h * 3);

    final Int32List tableR = Int32List(256);
    final Int32List tableG = Int32List(256);
    final Int32List tableB = Int32List(256);
    for (int i = 0; i < 256; i++) {
      tableR[i] = (i * gainR).round().clamp(0, 255);
      tableG[i] = (i * gainG).round().clamp(0, 255);
      tableB[i] = (i * gainB).round().clamp(0, 255);
    }

    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int outRow = y * w * 3;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int dest = outRow + x * 3;
        out[dest] = tableR[bytes[i]];
        out[dest + 1] = tableG[bytes[i + 1]];
        out[dest + 2] = tableB[bytes[i + 2]];
      }
    }

    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: out.buffer,
      numChannels: 3,
    );
  }

  /// Returns the histogram value at [percent] of the sample population.
  ///
  /// The histogram has 256 bins and [total] must match the number of samples
  /// used to build it. Percentiles are clamped to at least one sample so the
  /// first occupied bin is returned even for very small images.
  static int _percentile(List<int> histogram, int total, double percent) {
    if (total <= 0 || histogram.isEmpty) {
      return 0;
    }

    final int wanted = (total * percent / 100).round().clamp(1, total);
    int accumulated = 0;
    for (int i = 0; i < histogram.length; i++) {
      accumulated += histogram[i];
      if (accumulated >= wanted) {
        return i;
      }
    }
    return histogram.length - 1;
  }

  static double _balance(double target, double mean, double strength) {
    if (mean < 1) {
      return 1;
    }
    final double blended = 1 + (target / mean - 1) * strength;
    return blended.clamp(0.9, 1.12);
  }

  static Int32List _dilateInt(Int32List source, int width, int height, int radius) {
    final Int32List out = Int32List(width * height);
    for (int y = 0; y < height; y++) {
      final int y0 = y - radius < 0 ? 0 : y - radius;
      final int y1 = y + radius >= height ? height - 1 : y + radius;
      for (int x = 0; x < width; x++) {
        final int x0 = x - radius < 0 ? 0 : x - radius;
        final int x1 = x + radius >= width ? width - 1 : x + radius;
        int best = 0;
        for (int py = y0; py <= y1; py++) {
          final int row = py * width;
          for (int px = x0; px <= x1; px++) {
            final int value = source[row + px];
            if (value > best) {
              best = value;
            }
          }
        }
        out[y * width + x] = best;
      }
    }
    return out;
  }

  static Int32List _boxBlurInt(
    Int32List source,
    int width,
    int height,
    int radius,
  ) {
    final Int32List horizontal = Int32List(width * height);
    for (int y = 0; y < height; y++) {
      final int row = y * width;
      for (int x = 0; x < width; x++) {
        int acc = 0;
        int n = 0;
        for (int dx = -radius; dx <= radius; dx++) {
          final int px = x + dx;
          if (px < 0 || px >= width) {
            continue;
          }
          acc += source[row + px];
          n++;
        }
        horizontal[row + x] = acc ~/ n;
      }
    }

    final Int32List vertical = Int32List(width * height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int acc = 0;
        int n = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          final int py = y + dy;
          if (py < 0 || py >= height) {
            continue;
          }
          acc += horizontal[py * width + x];
          n++;
        }
        vertical[y * width + x] = acc ~/ n;
      }
    }
    return vertical;
  }
}
