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
/// rather than magenta or green), it is corrected less than brightness, and the
/// correction fades out where the background is too dark to measure. Detail for
/// the unsharp pass is taken from luminance alone, so sharpening cannot create
/// a colour edge.
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
  /// The brightness estimate uses the *brightest* pixels of each cell, dilated
  /// across neighbours, so dense ink never drags the background down â€” that is
  /// what leaves white halos around text blocks in a naive implementation. The
  /// grid is coarse on purpose.
  ///
  /// The estimate is built from the mean *colour* of those brightest pixels,
  /// not from three independent per-channel maxima. Taking the maximum of each
  /// channel separately describes a colour no pixel in the cell actually has,
  /// and the error grows with sensor noise; multiplying that error by the up to
  /// 2.8x shadow lift is what painted random green and magenta patches over
  /// slightly shadowed paper.
  ///
  /// Colour is then corrected far more cautiously than brightness:
  ///
  ///  * the cast is smoothed over a much wider area than the brightness, since
  ///    the colour of the light changes across a page far more slowly;
  ///  * cells that are not paper-coloured (pigment, a gold envelope) barely
  ///    vote, which is what keeps a pink form pink instead of "correcting" it
  ///    to grey;
  ///  * the correction is gated by how bright the local paper is, because in a
  ///    deep shadow the estimate cannot be told apart from noise. Whatever is
  ///    left over is handled by the global white balance in [toneMap].
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

    // Pass 1: the brightest *value* in each cell, where value is the darkest
    // of the three channels. Selecting on luminance would bias the result:
    // luminance weights green most heavily, so keeping the brightest pixels by
    // luminance keeps the greenest ones too, and the paper comes out green on
    // one cell and neutral on the next.
    final Int32List cellLevel = Int32List(cells);
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
        lumaSum += (r * 299 + g * 587 + b * 114) ~/ 1000;
        lumaCount++;
        final int level = math.min(r, math.min(g, b));
        final int index = cellRow + (x ~/ scale);
        if (level > cellLevel[index]) {
          cellLevel[index] = level;
        }
      }
    }
    final int grey = lumaCount == 0 ? 200 : (lumaSum / lumaCount).round();

    // Pass 2: mean RGB of the pixels within [paperSlice] levels of the cell's
    // brightest one. Averaging whole triples keeps the estimate a colour the
    // paper really has, and drops the noise by sqrt(n).
    const int paperSlice = 10;
    final Int32List sumR = Int32List(cells);
    final Int32List sumG = Int32List(cells);
    final Int32List sumB = Int32List(cells);
    final Int32List votes = Int32List(cells);
    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int cellRow = (y ~/ scale) * sw;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        final int index = cellRow + (x ~/ scale);
        final int r = bytes[i];
        final int g = bytes[i + 1];
        final int b = bytes[i + 2];
        if (math.min(r, math.min(g, b)) < cellLevel[index] - paperSlice) {
          continue;
        }
        sumR[index] += r;
        sumG[index] += g;
        sumB[index] += b;
        votes[index]++;
      }
    }

    final Int32List paperR = Int32List(cells);
    final Int32List paperG = Int32List(cells);
    final Int32List paperB = Int32List(cells);
    final Int32List paperLuma = Int32List(cells);
    for (int i = 0; i < cells; i++) {
      final int n = votes[i];
      paperR[i] = n == 0 ? grey : sumR[i] ~/ n;
      paperG[i] = n == 0 ? grey : sumG[i] ~/ n;
      paperB[i] = n == 0 ? grey : sumB[i] ~/ n;
      paperLuma[i] =
          (paperR[i] * 299 + paperG[i] * 587 + paperB[i] * 114) ~/ 1000;
    }

    // Brightness: a small dilation makes the estimate monotone across ink, then
    // a blur removes the blockiness of the downsampled grid.
    final Int32List background = _boxBlurInt(
      _dilateInt(paperLuma, sw, sh, 2),
      sw,
      sh,
      2,
    );

    // Colour: no dilation (that would pull one channel from a neighbour's
    // pigment and invent a colour), a wider blur, and a vote weighted by how
    // much each cell looks like paper.
    final Int32List castWeight = Int32List(cells);
    for (int i = 0; i < cells; i++) {
      final int r = paperR[i];
      final int g = paperG[i];
      final int b = paperB[i];
      final int hi = math.max(r, math.max(g, b));
      final int lo = math.min(r, math.min(g, b));
      final int saturation = hi <= 1 ? 0 : (hi - lo) * 100 ~/ hi;
      double weight = ((60 - saturation) / 22).clamp(0.0, 1.0);
      // Magenta / pink / green backgrounds are content, not a cast.
      weight *= _pigmentConfidence(r, g, b);
      weight *= ((paperLuma[i] - 30) / 40).clamp(0.0, 1.0);
      castWeight[i] = (weight * 256).round();
    }

    final Int32List castR = _weightedBlur(
      paperR,
      paperLuma,
      castWeight,
      sw,
      sh,
      3,
    );
    final Int32List castG = _weightedBlur(
      paperG,
      paperLuma,
      castWeight,
      sw,
      sh,
      3,
    );
    final Int32List castB = _weightedBlur(
      paperB,
      paperLuma,
      castWeight,
      sw,
      sh,
      3,
    );

    int total = 0;
    int counted = 0;
    for (int i = 0; i < cells; i++) {
      final int luma = background[i];
      if (luma > 1) {
        total += luma;
        counted++;
      }
    }
    final int meanBackground = counted == 0 ? 200 : total ~/ counted;

    // Paper should land near white, but never darken an already bright page.
    final int target = meanBackground < 215 ? 226 : meanBackground;

    // Per-cell gains, interpolated per pixel below. Applying a whole cell's
    // gain to every pixel inside it is what keeps three divisions and a square
    // root out of the 4 M pixel loop.
    final Int32List lift = Int32List(cells);
    final Int32List chromaLift = Int32List(cells);
    final Int32List gainR = Int32List(cells);
    final Int32List gainG = Int32List(cells);
    final Int32List gainB = Int32List(cells);
    for (int i = 0; i < cells; i++) {
      final int backgroundLuma = background[i].clamp(1, 255);
      // The lift is exact when it is not clamped: `target / background` puts a
      // shadowed cell on the same white as the lit ones, which is the whole
      // point of flattening. The clamp only limits how far sensor noise can be
      // amplified. 2.8 left the deepest corner of a page at ~175 instead of
      // white, so the limit is raised; colour is held back separately below.
      final double factor = (target / backgroundLuma).clamp(0.55, 4.0);
      lift[i] = (factor * 256).round();
      // Chroma is lifted *less* than luminance, and only when lifting: in a
      // shadow the exposure can be raised 4x, and sensor colour noise would be
      // raised with it. Keeping the hue and losing a little saturation in
      // shadow is what a real capture pipeline does, and it is invisible next
      // to coloured blotches on what should be grey paper. The extra 0.6 power
      // plus a hard 1.9 cap means the deepest shadow still gains brightness
      // without gaining enough colour gain to make noise visible.
      final double chromaFactor = factor <= 1
          ? factor
          : math.min(math.pow(factor, 0.6).toDouble(), 1.9);
      chromaLift[i] = (chromaFactor * 256).round();

      final int red = (background[i] + castR[i]).clamp(24, 255);
      final int green = (background[i] + castG[i]).clamp(24, 255);
      final int blue = (background[i] + castB[i]).clamp(24, 255);
      final int bgLuma = (red * 299 + green * 587 + blue * 114) ~/ 1000;

      // How much of the local colour is light rather than pigment.
      final int hi = math.max(red, math.max(green, blue));
      final int lo = math.min(red, math.min(green, blue));
      final int saturation = hi <= 1 ? 0 : (hi - lo) * 100 ~/ hi;
      double confidence = ((60 - saturation) / 22).clamp(0.0, 1.0);
      confidence *= _pigmentConfidence(red, green, blue);
      // A dark background cannot be measured reliably enough to correct its
      // colour, so the correction still fades out downwards -- but the estimate
      // is a mean over the paper-like pixels of a cell rather than a per-channel
      // maximum, so it stays usable much deeper into a shadow than it used to.
      // Fading from 30 rather than 45 is what takes the warm cast out of a
      // corner shadow that the 4x lift has already brought up to near white.
      confidence *= ((bgLuma - 30) / 45).clamp(0.0, 1.0);

      final double gR = (1 + (bgLuma / red - 1) * confidence).clamp(0.84, 1.24);
      final double gG = (1 + (bgLuma / green - 1) * confidence).clamp(0.84, 1.24);
      final double gB = (1 + (bgLuma / blue - 1) * confidence).clamp(0.84, 1.24);
      gainR[i] = (gR * 256).round();
      gainG[i] = (gG * 256).round();
      gainB[i] = (gB * 256).round();
    }

    final Uint8List out = Uint8List(w * h * 3);

    // The gain grid is [scale] times coarser than the page, so a whole block of
    // pixels shares the same four cells. Resolving the column indices once
    // keeps the per-pixel loop down to the interpolation itself.
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
      final int invY = 256 - wy;

      for (int x = 0; x < w; x++) {
        final int x0 = colLeft[x];
        final int x1 = colRight[x];
        final int wx = colWeight[x];
        final int invX = 256 - wx;

        int mix(Int32List grid) =>
            ((grid[rowTop + x0] * invX + grid[rowTop + x1] * wx) * invY +
                (grid[rowBottom + x0] * invX + grid[rowBottom + x1] * wx) *
                    wy) >>
            16;

        final int lf = mix(lift);
        final int cf = mix(chromaLift);

        final int i = row + x * 3;
        final int dest = outRow + x * 3;

        // White balance first: it is luma-preserving on the *background*, so
        // the shadow lift below cannot turn a small cast correction into a
        // saturation change.
        final int red = (bytes[i] * mix(gainR)) >> 8;
        final int green = (bytes[i + 1] * mix(gainG)) >> 8;
        final int blue = (bytes[i + 2] * mix(gainB)) >> 8;
        final int luma = (red * 299 + green * 587 + blue * 114) ~/ 1000;

        out[dest] = ((luma * lf + (red - luma) * cf + 128) >> 8).clamp(0, 255);
        out[dest + 1] =
            ((luma * lf + (green - luma) * cf + 128) >> 8).clamp(0, 255);
        out[dest + 2] =
            ((luma * lf + (blue - luma) * cf + 128) >> 8).clamp(0, 255);
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
        if (saturation > 24 || _isPigment(r, g, b)) {
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
        if (saturation <= 28 && !_isPigment(r, g, b)) {
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

          // Grey pixels have no chroma to expand, only noise. Ramping the
          // expansion in with existing chroma is what keeps a slightly
          // shadowed area from turning into coloured blotches: a real colour
          // block or a pink form is far past this threshold and still gets the
          // full 1.5x.
          final int peakChroma = math.max(up, down);
          final double presence = ((peakChroma - 6) / 12).clamp(0.0, 1.0);
          double factor = 1 + (saturation - 1) * presence;
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
        if (saturation > 24 || _isPigment(r, g, b)) {
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
  /// The detail is measured on luminance and added, unchanged, to all three
  /// channels. Sharpening R, G and B independently sharpens colour edges too,
  /// which is what used to leave cyan and magenta rims around black text and
  /// exaggerate colour noise in shadow; one luminance delta cannot shift hue.
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
    final int amount256 = (amount * 256).round();

    final Uint8List luma = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int lumaRow = y * w;
      for (int x = 0; x < w; x++) {
        final int i = row + x * 3;
        luma[lumaRow + x] =
            (bytes[i] * 299 + bytes[i + 1] * 587 + bytes[i + 2] * 114) ~/ 1000;
      }
    }

    final Uint8List out = Uint8List(w * h * 3);
    for (int y = 0; y < h; y++) {
      final int row = y * stride;
      final int outRow = y * w * 3;
      final int lumaRow = y * w;
      final int lumaUp = (y > 0 ? y - 1 : y) * w;
      final int lumaDown = (y < h - 1 ? y + 1 : y) * w;

      for (int x = 0; x < w; x++) {
        final int centre = luma[lumaRow + x];
        final int soft =
            (luma[lumaRow + (x > 0 ? x - 1 : x)] +
                luma[lumaRow + (x < w - 1 ? x + 1 : x)] +
                luma[lumaUp + x] +
                luma[lumaDown + x] +
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
        final int delta = detail * amount256 ~/ 256;
        final int i = row + x * 3;
        final int dest = outRow + x * 3;
        out[dest] = (bytes[i] + delta).clamp(0, 255);
        out[dest + 1] = (bytes[i + 1] + delta).clamp(0, 255);
        out[dest + 2] = (bytes[i + 2] + delta).clamp(0, 255);
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

  /// True when the middle channel sits clearly above or below both of the
  /// others: a green or magenta cast of pigment rather than a plausible light
  /// source. A one-level rounding difference must not qualify, or a perfectly
  /// neutral page can drop out of its own white-point estimate.
  static bool _isPigment(int r, int g, int b) {
    return math.min(r - g, b - g) > 2 || math.min(g - r, g - b) > 2;
  }

  /// How much a background colour may be trusted as light rather than pigment.
  ///
  /// The same test as [_isPigment], but continuous. A hard threshold applied to
  /// a noisy per-cell estimate turns noise into structure: neighbouring cells
  /// land on opposite sides of it and the shadow comes out blotchy. Fading the
  /// correction out over ten levels instead makes that impossible.
  static double _pigmentConfidence(int r, int g, int b) {
    final int excess = math.max(
      math.min(r - g, b - g),
      math.min(g - r, g - b),
    );
    return 1 - ((excess - 2) / 10).clamp(0.0, 1.0);
  }

  static double _balance(double target, double mean, double strength) {
    if (mean < 1) {
      return 1;
    }
    final double blended = 1 + (target / mean - 1) * strength;
    return blended.clamp(0.9, 1.12);
  }

  /// Box blur of `value - reference`, averaged only over cells that carry a
  /// weight. Cells with a zero weight are ignored rather than pulling the
  /// result towards zero, and a window with no weighted cell at all comes out
  /// neutral.
  ///
  /// This is how the colour of the light is estimated: the brightness of a page
  /// changes quickly (that is the shadow being removed), its colour changes
  /// slowly, so the cast can be smoothed over a much wider area than the
  /// brightness without losing the shadow's shape.
  static Int32List _weightedBlur(
    Int32List value,
    Int32List reference,
    Int32List weight,
    int width,
    int height,
    int radius,
  ) {
    final int n = width * height;
    final Int32List difference = Int32List(n);
    for (int i = 0; i < n; i++) {
      difference[i] = value[i] - reference[i];
    }

    final Int32List horizontal = Int32List(n);
    final Int32List horizontalWeight = Int32List(n);
    for (int y = 0; y < height; y++) {
      final int row = y * width;
      for (int x = 0; x < width; x++) {
        int sum = 0;
        int total = 0;
        for (int dx = -radius; dx <= radius; dx++) {
          final int px = x + dx;
          if (px < 0 || px >= width) {
            continue;
          }
          final int w = weight[row + px];
          if (w == 0) {
            continue;
          }
          sum += difference[row + px] * w;
          total += w;
        }
        horizontal[row + x] = sum;
        horizontalWeight[row + x] = total;
      }
    }

    final Int32List out = Int32List(n);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int sum = 0;
        int total = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          final int py = y + dy;
          if (py < 0 || py >= height) {
            continue;
          }
          sum += horizontal[py * width + x];
          total += horizontalWeight[py * width + x];
        }
        out[y * width + x] = total == 0 ? 0 : sum ~/ total;
      }
    }
    return out;
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
