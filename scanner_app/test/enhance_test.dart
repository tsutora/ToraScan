import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

/// A synthetic "photo of a page": light paper with dark text-like bars and a
/// darker corner, so each preset has something real to work on.
Uint8List samplePage() {
  final img.Image image = img.Image(width: 160, height: 220);

  img.fill(image, color: img.ColorRgb8(206, 200, 190));
  img.fillRect(
    image,
    x1: 0,
    y1: 180,
    x2: 159,
    y2: 219,
    color: img.ColorRgb8(150, 145, 138),
  );

  for (int line = 0; line < 8; line++) {
    final int top = 20 + line * 18;
    img.fillRect(
      image,
      x1: 16,
      y1: top,
      x2: 140,
      y2: top + 7,
      color: img.ColorRgb8(45, 45, 48),
    );
  }

  return img.encodeJpg(image);
}

double _cornerMean(img.Image image, int x0, int y0) {
  final int side = image.width ~/ 4;
  double sum = 0;
  int n = 0;
  for (int y = y0; y < y0 + side; y++) {
    for (int x = x0; x < x0 + side; x++) {
      sum += image.getPixel(x, y).luminance;
      n++;
    }
  }
  return sum / n;
}

void main() {
  for (final ScanPreset preset in ScanPreset.values) {
    test('${preset.name} returns a decodable JPEG', () {
      final Uint8List output = ImagePipeline.processPreset(
        samplePage(),
        preset,
      );

      expect(output, isNotEmpty);
      final img.Image? decoded = img.decodeImage(output);
      expect(decoded, isNotNull);
      expect(decoded!.width, 160);
      expect(decoded.height, 220);
    });
  }

  test('blackWhite pushes pixels to the extremes', () {
    final Uint8List output = ImagePipeline.processPreset(
      samplePage(),
      ScanPreset.blackWhite,
    );
    final img.Image decoded = img.decodeImage(output)!;

    int midTones = 0;
    int total = 0;
    for (final img.Pixel pixel in decoded) {
      total++;
      if (pixel.r > 90 && pixel.r < 165) {
        midTones++;
      }
    }

    // JPEG ringing leaves a few grey edge pixels; the page itself should be
    // overwhelmingly black or white.
    expect(midTones / total, lessThan(0.12));
  });

  test('gray removes chroma', () {
    final Uint8List output = ImagePipeline.processPreset(
      samplePage(),
      ScanPreset.grayscale,
    );
    final img.Image decoded = img.decodeImage(output)!;

    int coloured = 0;
    for (final img.Pixel pixel in decoded) {
      if ((pixel.r - pixel.g).abs() > 12 || (pixel.g - pixel.b).abs() > 12) {
        coloured++;
      }
    }
    expect(coloured, lessThan(decoded.width * decoded.height * 0.02));
  });

  test('auto survives a flat page', () {
    final img.Image flat = img.Image(width: 64, height: 64);
    img.fill(flat, color: img.ColorRgb8(150, 150, 150));

    final Uint8List output = ImagePipeline.processPreset(
      img.encodeJpg(flat),
      ScanPreset.auto,
    );
    final img.Image decoded = img.decodeImage(output)!;

    expect(decoded.width, 64);
    expect(decoded.height, 64);
    // A page with no ink has no black point to anchor to. It must come back
    // close to its own brightness, never as a black rectangle.
    expect(decoded.getPixel(32, 32).luminance, greaterThan(120));
  });

  test('an oversized page is downscaled to the cap', () {
    final img.Image big = img.Image(width: 3200, height: 2400);
    img.fill(big, color: img.ColorRgb8(240, 240, 240));

    final Uint8List output = ImagePipeline.processPreset(
      img.encodeJpg(big),
      ScanPreset.none,
    );
    final img.Image decoded = img.decodeImage(output)!;

    expect(decoded.width, ImagePipeline.maxDimension);
    expect(decoded.height, lessThan(ImagePipeline.maxDimension));
  });

  test('auto keeps dark ink neutral (no colour fringing)', () {
    final img.Image page = img.Image(width: 140, height: 140);
    img.fill(page, color: img.ColorRgb8(235, 232, 226));
    img.fillRect(
      page,
      x1: 20,
      y1: 60,
      x2: 120,
      y2: 80,
      color: img.ColorRgb8(38, 38, 44),
    );

    final Uint8List output = ImagePipeline.processPreset(
      img.encodeJpg(page),
      ScanPreset.auto,
    );
    final img.Image decoded = img.decodeImage(output)!;

    int dark = 0;
    int fringed = 0;
    for (final img.Pixel pixel in decoded) {
      if (pixel.luminance >= 90) {
        continue;
      }
      dark++;
      final num hi = pixel.r > pixel.g
          ? (pixel.r > pixel.b ? pixel.r : pixel.b)
          : (pixel.g > pixel.b ? pixel.g : pixel.b);
      final num lo = pixel.r < pixel.g
          ? (pixel.r < pixel.b ? pixel.r : pixel.b)
          : (pixel.g < pixel.b ? pixel.g : pixel.b);
      if (hi - lo > 28) {
        fringed++;
      }
    }

    expect(dark, greaterThan(100));
    expect(fringed, 0);
  });

  test('auto flattens uneven lighting', () {
    final img.Image page = img.Image(width: 200, height: 200);
    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 200; x++) {
        final double shade = 1 - 0.45 * (x / 199);
        final int value = (240 * shade).round();
        page.setPixelRgb(x, y, value, value, value);
      }
    }

    final Uint8List source = img.encodeJpg(page);
    final img.Image before = img.decodeImage(source)!;
    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(source, ScanPreset.auto),
    )!;

    final int side = before.width ~/ 4;
    final double deltaBefore =
        (_cornerMean(before, 0, 0) -
                _cornerMean(before, before.width - side, before.height - side))
            .abs();
    final double deltaAfter =
        (_cornerMean(after, 0, 0) -
                _cornerMean(after, after.width - side, after.height - side))
            .abs();

    expect(deltaBefore, greaterThan(30));
    expect(deltaAfter, lessThan(deltaBefore * 0.5));
  });

  /// A page under a warm lamp, with a warm shadow falling across the left
  /// side: the paper is neutral, but the shadow is both darker and yellower,
  /// because it is lit only by warm light bounced off a desk.
  img.Image warmShadowPage({double floor = 0.35}) {
    final img.Image page = img.Image(width: 240, height: 320);
    for (int y = 0; y < 320; y++) {
      for (int x = 0; x < 240; x++) {
        final double lit = floor + (1 - floor) * (x / 239);
        page.setPixelRgb(
          x,
          y,
          (245 * lit + 30 * (1 - lit)).round().clamp(0, 255),
          (243 * lit + 20 * (1 - lit)).round().clamp(0, 255),
          (240 * lit + 8 * (1 - lit)).round().clamp(0, 255),
        );
      }
    }
    for (int line = 0; line < 6; line++) {
      final int top = 30 + line * 40;
      img.fillRect(
        page,
        x1: 40,
        y1: top,
        x2: 200,
        y2: top + 12,
        color: img.ColorRgb8(60, 58, 56),
      );
    }
    return page;
  }

  ({double r, double g, double b}) meanIn(
    img.Image image,
    int x0,
    int x1,
    int y0,
    int y1,
  ) {
    double r = 0;
    double g = 0;
    double b = 0;
    int n = 0;
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final img.Pixel p = image.getPixel(x, y);
        r += p.r;
        g += p.g;
        b += p.b;
        n++;
      }
    }
    return (r: r / n, g: g / n, b: b / n);
  }

  test('auto leaves no yellow cast in a warm shadow', () {
    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(
        img.encodeJpg(warmShadowPage()),
        ScanPreset.auto,
      ),
    )!;

    // Bare paper in the shadowed band, above the first line of text.
    final shadow = meanIn(after, 4, 34, 4, 24);
    final lit = meanIn(after, 200, 236, 4, 24);

    // Neutral means the three channels agree; a warm cast shows up as red
    // running ahead of blue.
    expect((shadow.r - shadow.b).abs(), lessThan(9));
    expect((shadow.g - shadow.b).abs(), lessThan(9));
    expect((lit.r - lit.b).abs(), lessThan(9));
    // ...and the shadow is actually lifted, not merely neutralised by
    // crushing it to black.
    expect(shadow.r, greaterThan(170));
  });

  test('auto keeps a printed colour block from being washed out', () {
    final img.Image page = warmShadowPage(floor: 0.6);
    img.fillRect(
      page,
      x1: 70,
      y1: 100,
      x2: 170,
      y2: 200,
      color: img.ColorRgb8(200, 40, 40),
    );

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;
    final block = meanIn(after, 90, 150, 120, 180);

    // Red must stay red: the illumination estimate is only allowed to
    // neutralise light-coloured paper, not pigment.
    expect(block.r - block.g, greaterThan(80));
    expect(block.r - block.b, greaterThan(80));
  });

  test('auto brings underexposed paper up to white', () {
    // A page photographed a stop and a half dark: the paper sits near 200, not
    // near white. A fixed white point would leave the whole page grey — the
    // difference between a scan and a photograph of a scan.
    final img.Image page = img.Image(width: 200, height: 260);
    img.fill(page, color: img.ColorRgb8(200, 198, 196));
    for (int line = 0; line < 6; line++) {
      final int top = 20 + line * 36;
      img.fillRect(
        page,
        x1: 20,
        y1: top,
        x2: 180,
        y2: top + 12,
        color: img.ColorRgb8(70, 70, 72),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    // Bare paper in the left margin, and the inside of the first text bar.
    final paper = meanIn(after, 2, 16, 2, 256);
    final ink = meanIn(after, 40, 160, 24, 30);

    expect(paper.r, greaterThan(244), reason: 'paper should be white');
    expect(paper.g, greaterThan(244));
    expect(paper.b, greaterThan(244));
    expect(ink.r, lessThan(45), reason: 'ink should be black');
  });

  test('auto keeps a pink form pink', () {
    // A pink form with white margins. The pink must not be mistaken for a
    // warm light cast and neutralised: it is the content the user photographed.
    final img.Image page = img.Image(width: 240, height: 320);
    img.fill(page, color: img.ColorRgb8(246, 202, 214));
    img.fillRect(
      page,
      x1: 0,
      y1: 0,
      x2: 239,
      y2: 34,
      color: img.ColorRgb8(246, 244, 242),
    );
    img.fillRect(
      page,
      x1: 0,
      y1: 290,
      x2: 239,
      y2: 319,
      color: img.ColorRgb8(246, 244, 242),
    );
    for (int line = 0; line < 5; line++) {
      final int top = 70 + line * 44;
      img.fillRect(
        page,
        x1: 30,
        y1: top,
        x2: 214,
        y2: top + 12,
        color: img.ColorRgb8(52, 52, 58),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    final pink = meanIn(after, 8, 28, 130, 150);
    final paper = meanIn(after, 60, 180, 2, 26);

    // Pink means red clearly ahead of green; a neutralised form would have all
    // three channels converge.
    expect(pink.r - pink.g, greaterThan(25), reason: 'pink must stay pink');
    expect(pink.r - pink.b, greaterThan(5));
    expect(pink.r, greaterThan(200));
    // The white margin is still the page's white point.
    expect(paper.g, greaterThan(236));
    expect((paper.r - paper.b).abs(), lessThan(9));
  });

  test('auto does not lift dense ink into a grey veil', () {
    // A bold heading is darker than the 16 px background grid. If the
    // estimate is allowed to take its cue from the ink, the whole block is
    // lifted and a grey veil appears behind the text.
    final img.Image page = img.Image(width: 240, height: 300);
    img.fill(page, color: img.ColorRgb8(224, 222, 218));
    img.fillRect(
      page,
      x1: 40,
      y1: 60,
      x2: 200,
      y2: 140,
      color: img.ColorRgb8(46, 46, 50),
    );

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    final ink = meanIn(after, 70, 170, 80, 120);
    final paper = meanIn(after, 4, 30, 4, 290);

    expect(ink.r, lessThan(60), reason: 'dense ink must stay dark');
    expect(ink.r - ink.b, lessThan(20));
    expect(paper.r, greaterThan(240));
  });

  test('auto lifts a shadow lying along the page edge', () {
    // A phone held over the page throws its shadow down one edge, past its own
    // bright rim, and the sliver of paper beyond that rim is lit again. The
    // paper inside the band has to set its own level: an estimate that always
    // takes the brightest neighbour reaches 30 px into the band, finds the lit
    // sliver, and decides the shadow is paper -- which is how a grey stripe
    // survives down the edge of an otherwise white page.
    const int w = 800;
    const int h = 1000;
    final img.Image page = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double fx = x / (w - 1);
        double shade = 1;
        if (fx > 0.60 && fx < 0.86) {
          // The penumbra, deepest just inside the rim.
          final double t = (fx - 0.60) / 0.26;
          shade = 1 - 0.30 * math.sin(t * math.pi);
        }
        page.setPixelRgb(
          x,
          y,
          (228 * shade).round(),
          (225 * shade).round(),
          (219 * shade).round(),
        );
      }
    }
    // Some ink, so the tone map has a black point to anchor to; without it a
    // blank page is deliberately left where the flatten put it.
    for (int line = 0; line < 6; line++) {
      final int top = (h * (0.10 + line * 0.14)).round();
      img.fillRect(
        page,
        x1: (w * 0.08).round(),
        y1: top,
        x2: (w * 0.55).round(),
        y2: top + (h * 0.015).round(),
        color: img.ColorRgb8(44, 44, 48),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    final band = meanIn(after, (w * 0.70).round(), (w * 0.82).round(), 300, 700);
    final lit = meanIn(after, (w * 0.30).round(), (w * 0.50).round(), 300, 700);
    final double bandLuma = band.r * 0.299 + band.g * 0.587 + band.b * 0.114;
    final double litLuma = lit.r * 0.299 + lit.g * 0.587 + lit.b * 0.114;

    expect(
      bandLuma,
      greaterThan(240),
      reason: 'the shadow along the edge is still there: '
          '${bandLuma.toStringAsFixed(1)}',
    );
    expect(
      litLuma - bandLuma,
      lessThan(8),
      reason: 'the shadowed band is '
          '${(litLuma - bandLuma).toStringAsFixed(1)} levels darker',
    );
  });

  test('colour keeps pigment as saturated in a shadow as in the light', () {
    // The whole point of the colour filter: a page whose colour is the subject.
    // Enhanced lifts a shadow's brightness more than its chroma, which is
    // right for a document but leaves the same ink looking washed out on the
    // shaded half. Colour scales both by the same factor, so a block keeps its
    // place on the hue wheel and its strength across the shadow boundary.
    const int w = 640;
    const int h = 480;
    final img.Image page = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double shade = x < w ~/ 2 ? 1 : 0.55;
        final bool block =
            x > (w * 0.15).round() &&
            x < (w * 0.85).round() &&
            y > (h * 0.30).round() &&
            y < (h * 0.70).round();
        final int r = ((block ? 196 : 232) * shade).round();
        final int g = ((block ? 44 : 228) * shade).round();
        final int b = ((block ? 60 : 221) * shade).round();
        page.setPixelRgb(x, y, r, g, b);
      }
    }

    double saturation(img.Image image, int x0, int x1) {
      final ({double r, double g, double b}) mean =
          meanIn(image, x0, x1, (h * 0.40).round(), (h * 0.60).round());
      final double hi = math.max(mean.r, math.max(mean.g, mean.b));
      final double lo = math.min(mean.r, math.min(mean.g, mean.b));
      return hi <= 0 ? 0 : (hi - lo) / hi;
    }

    final img.Image enhanced = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;
    final img.Image colour = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.colour),
    )!;

    final double enhancedGap =
        (saturation(enhanced, 60, 200) - saturation(enhanced, 440, 580)).abs();
    final double colourGap =
        (saturation(colour, 60, 200) - saturation(colour, 440, 580)).abs();

    expect(
      saturation(colour, 440, 580),
      greaterThan(0.30),
      reason: 'the shadowed half of the block must stay a strong red',
    );
    expect(
      colourGap,
      lessThan(0.09),
      reason: 'colour drifted across the shadow boundary by '
          '${colourGap.toStringAsFixed(3)} '
          '(enhanced: ${enhancedGap.toStringAsFixed(3)})',
    );
    expect(
      colourGap,
      lessThan(enhancedGap * 0.7),
      reason: 'colour should drift clearly less than enhanced: '
          '${colourGap.toStringAsFixed(3)} vs '
          '${enhancedGap.toStringAsFixed(3)}',
    );
  });

  test('auto does not boost the colour of the paper itself', () {
    // White paper is never neutral: light, sensor and the stock all leave a
    // few levels of chroma, and it varies across the page. Expanding chroma
    // wherever it exists turns that variation into coloured clouds, which is
    // what made a plain white cover look stained. Paper must come out no more
    // coloured than it went in; only pigment is allowed to grow.
    const int w = 640;
    const int h = 480;
    final img.Image page = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double mottle =
            math.sin(x / 47 * 2 * math.pi) * math.sin(y / 61 * 2 * math.pi);
        final int dr = (7 * mottle).round();
        page.setPixelRgb(x, y, 236 + dr, 230, 224 - dr);
      }
    }
    for (int line = 0; line < 6; line++) {
      final int top = (h * (0.10 + line * 0.14)).round();
      img.fillRect(
        page,
        x1: (w * 0.10).round(),
        y1: top,
        x2: (w * 0.90).round(),
        y2: top + (h * 0.02).round(),
        color: img.ColorRgb8(44, 44, 48),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    // Paper between two of the text lines, away from the bars.
    double chroma(img.Image image) {
      double sum = 0;
      int n = 0;
      for (int y = (h * 0.26).round(); y < (h * 0.36).round(); y += 2) {
        for (int x = (w * 0.20).round(); x < (w * 0.80).round(); x += 2) {
          final img.Pixel p = image.getPixel(x, y);
          sum += (p.r - p.b).abs();
          n++;
        }
      }
      return sum / n;
    }

    final double before = chroma(page);
    final double got = chroma(after);

    expect(
      got,
      lessThan(before * 1.02),
      reason: 'paper chroma grew from '
          '${before.toStringAsFixed(1)} to ${got.toStringAsFixed(1)}',
    );
  });

  test('toneMap expands chroma around the pixel luminance', () {
    // CamScanner's colour pass maps each channel to Y + 1.5 * (C - Y), which
    // is a pure saturation boost: hue is untouched, only its distance from the
    // pixel's own brightness grows.
    final img.Image flat = img.Image(width: 8, height: 8);
    img.fill(flat, color: img.ColorRgb8(200, 120, 120));

    final img.Image before = flat;
    final img.Image after = ImagePipeline.toneMap(flat, saturation: 1.5);

    final num gapBefore = before.getPixel(4, 4).r - before.getPixel(4, 4).g;
    final num gapAfter = after.getPixel(4, 4).r - after.getPixel(4, 4).g;

    expect(gapAfter, greaterThan(gapBefore + 20));
    // Green and blue started equal and must stay equal: no hue rotation.
    expect(
      (after.getPixel(4, 4).g - after.getPixel(4, 4).b).abs(),
      lessThan(3),
    );
  });

  test('asymmetric sharpening deepens ink without a white rim', () {
    final img.Image page = img.Image(width: 9, height: 9);
    img.fill(page, color: img.ColorRgb8(200, 200, 200));
    page.setPixelRgb(4, 4, 150, 150, 150);

    final img.Image symmetric = ImagePipeline.sharpen(page);
    final img.Image asymmetric = ImagePipeline.sharpen(page, asymmetric: true);

    expect(
      asymmetric.getPixel(4, 4).r,
      lessThan(symmetric.getPixel(4, 4).r - 10),
      reason: 'dark detail is amplified',
    );
    // The neighbouring paper pixel is slightly brighter than its surroundings
    // (positive detail); the asymmetric rule halves it instead of boosting it,
    // so it stays at paper level rather than gaining a halo.
    expect(asymmetric.getPixel(4, 3).r, lessThanOrEqualTo(202));
  });

  /// A page as a phone actually captures it: neutral paper, a soft shadow over
  /// part of it, and the independent per-channel noise of a small sensor.
  img.Image noisyShadowPage({double shadowFloor = 0.35, double noise = 5}) {
    final img.Image page = img.Image(width: 300, height: 400);
    int state = 20261108;
    double next() {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state / 0x7fffffff;
    }

    double bell() => (next() + next() + next() - 1.5) / 1.5;

    for (int y = 0; y < 400; y++) {
      for (int x = 0; x < 300; x++) {
        final double u = x / 299;
        final double shadow = (1 - u / 0.45).clamp(0.0, 1.0);
        final double lit = 1 - (1 - shadowFloor) * shadow;
        final int base = (222 * lit).round();
        page.setPixelRgb(
          x,
          y,
          (base + (bell() * noise).round()).clamp(0, 255),
          (base + (bell() * noise).round()).clamp(0, 255),
          (base + (bell() * noise).round()).clamp(0, 255),
        );
      }
    }
    for (int line = 0; line < 8; line++) {
      final int top = 20 + line * 46;
      img.fillRect(
        page,
        x1: 30,
        y1: top,
        x2: 270,
        y2: top + 8,
        color: img.ColorRgb8(48, 48, 52),
      );
    }
    return page;
  }

  ({double mean, int worst, double over}) bandChroma(
    img.Image image, {
    int x0 = 2,
    int x1 = 26,
    int y0 = 60,
    int y1 = 340,
  }) {
    double sum = 0;
    int total = 0;
    int worst = 0;
    int over = 0;
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final img.Pixel p = image.getPixel(x, y);
        final int hi = math.max(p.r.toInt(), math.max(p.g.toInt(), p.b.toInt()));
        final int lo = math.min(p.r.toInt(), math.min(p.g.toInt(), p.b.toInt()));
        final int chroma = hi - lo;
        sum += chroma;
        total++;
        if (chroma > worst) {
          worst = chroma;
        }
        if (chroma > 12) {
          over++;
        }
      }
    }
    return (mean: sum / total, worst: worst, over: over / total);
  }

  test('auto does not paint colour into a shadow', () {
    // The defect this guards: paper that is merely shaded came back with
    // random green and magenta patches. Paper is neutral in both bands here, so
    // every unit of chroma in the shadow was invented by the pipeline.
    for (final double floor in <double>[0.55, 0.35, 0.20]) {
      final img.Image after = img.decodeImage(
        ImagePipeline.processPreset(
          img.encodeJpg(noisyShadowPage(shadowFloor: floor)),
          ScanPreset.auto,
        ),
      )!;
      final ({double mean, int worst, double over}) shadow = bandChroma(after);

      expect(
        shadow.mean,
        lessThan(4),
        reason: 'floor $floor: mean chroma ${shadow.mean.toStringAsFixed(1)}',
      );
      expect(
        shadow.over,
        lessThan(0.01),
        reason: 'floor $floor: '
            '${(shadow.over * 100).toStringAsFixed(1)}% of the shadow is visibly coloured',
      );
      expect(shadow.worst, lessThan(22));
    }
  });

  test('auto lifts a deep corner shadow all the way to white', () {
    // A page shot with the hand shading one corner: the paper there is about
    // 3.5x darker than the lit side, and the shade is warm because the light
    // is. Both the darkness and the tint have to go, or the corner reads as a
    // grey smudge on an otherwise white page.
    //
    // The page has to be large enough that the 16 px estimate grid is small
    // compared with the shadow, as it is on a real 8 MP capture. On a tiny
    // canvas one cell of dilation reaches across the whole gradient and the
    // shadow is never really underestimated.
    const int w = 720;
    const int h = 960;
    final img.Image page = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double dx = x / (w - 1);
        final double dy = y / (h - 1);
        final double corner = math.sqrt(dx * dx + dy * dy) / math.sqrt(2);
        final double shade = 1 - 0.75 * corner;
        page.setPixelRgb(
          x,
          y,
          (232 * shade).round().clamp(0, 255),
          (228 * shade).round().clamp(0, 255),
          (220 * shade).round().clamp(0, 255),
        );
      }
    }
    for (int line = 0; line < 6; line++) {
      img.fillRect(
        page,
        x1: (w * 0.1).round(),
        y1: (h * (0.1 + line * 0.12)).round(),
        x2: (w * 0.9).round(),
        y2: (h * (0.1 + line * 0.12)).round() + (h * 0.02).round(),
        color: img.ColorRgb8(40, 40, 44),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    // Mean of the shaded corner, well inside the crop.
    double r = 0;
    double g = 0;
    double b = 0;
    int n = 0;
    for (int y = (h * 0.85).round(); y < (h * 0.98).round(); y++) {
      for (int x = (w * 0.85).round(); x < (w * 0.98).round(); x++) {
        final img.Pixel p = after.getPixel(x, y);
        r += p.r;
        g += p.g;
        b += p.b;
        n++;
      }
    }
    r /= n;
    g /= n;
    b /= n;
    final double luma = r * 0.299 + g * 0.587 + b * 0.114;
    final double cast = math.max(
      (r - g).abs(),
      math.max((r - b).abs(), (g - b).abs()),
    );

    expect(
      luma,
      greaterThan(232),
      reason: 'the corner is still shaded: '
          '${r.toStringAsFixed(0)},${g.toStringAsFixed(0)},'
          '${b.toStringAsFixed(0)}',
    );
    expect(cast, lessThan(12), reason: 'the corner is still warm');
  });

  test('auto lifts a shadow under the paper\'s own specular sparkle', () {
    // The other way the illumination estimate can fail, and the one that
    // produced the grey text block on a real A52s capture: paper is not a
    // flat surface. Under a lamp it sparkles, and a phone sensor records a
    // few near-white pixels in every 16 px cell. A paper level taken from the
    // cell *maximum* is then pinned at 255 in the shadowed text column too, so
    // the shadow is never lifted -- the margins come out white and the block
    // behind the text stays grey, which reads as a shadow pasted behind the
    // letters. The level has to come from a high percentile of the cell, not
    // its brightest pixel.
    const int w = 960;
    const int h = 1280;
    final img.Image page = img.Image(width: w, height: h);
    final math.Random random = math.Random(11);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double across = ((x / (w - 1)) - 0.10) / 0.80;
        final double shade = 1 -
            0.45 * (across <= 0 || across >= 1 ? 0 : math.sin(across * math.pi));
        int r = (226 * shade).round();
        int g = (222 * shade).round();
        int b = (216 * shade).round();
        if (random.nextDouble() < 0.012) {
          r = math.min(255, r + 60);
          g = math.min(255, g + 60);
          b = math.min(255, b + 60);
        }
        page.setPixelRgb(x, y, r, g, b);
      }
    }
    for (int line = 0; line < 6; line++) {
      final int top = (h * (0.10 + line * 0.12)).round();
      img.fillRect(
        page,
        x1: (w * 0.16).round(),
        y1: top,
        x2: (w * 0.84).round(),
        y2: top + (h * 0.02).round(),
        color: img.ColorRgb8(42, 42, 46),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    // Paper between two lines, inside the shadow, against the lit margin.
    final int y0 = (h * 0.49).round();
    final int y1 = (h * 0.575).round();
    final block = meanIn(after, (w * 0.20).round(), (w * 0.80).round(), y0, y1);
    final margin = meanIn(after, (w * 0.01).round(), (w * 0.09).round(), y0, y1);
    final double blockLuma =
        block.r * 0.299 + block.g * 0.587 + block.b * 0.114;
    final double marginLuma =
        margin.r * 0.299 + margin.g * 0.587 + margin.b * 0.114;

    expect(
      blockLuma,
      greaterThan(240),
      reason: 'the shadow behind the text is still there: '
          '${blockLuma.toStringAsFixed(1)}',
    );
    expect(
      marginLuma - blockLuma,
      lessThan(8),
      reason: 'the text block is ${(marginLuma - blockLuma).toStringAsFixed(1)} '
          'levels darker than the margins',
    );
  });

  /// Largest difference between the mean R, G and B of any block. A blotch is
  /// a region that has drifted off grey, not a single noisy pixel, so this is
  /// the measurement that matters for colour the pipeline invents.
  double worstBlockCast(img.Image image, int block) {
    double worst = 0;
    for (int by = 0; by + block <= image.height; by += block) {
      for (int bx = 0; bx + block <= image.width; bx += block) {
        double r = 0;
        double g = 0;
        double b = 0;
        for (int y = by; y < by + block; y++) {
          for (int x = bx; x < bx + block; x++) {
            final img.Pixel p = image.getPixel(x, y);
            r += p.r;
            g += p.g;
            b += p.b;
          }
        }
        final int n = block * block;
        r /= n;
        g /= n;
        b /= n;
        final double cast = math.max(
          (r - g).abs(),
          math.max((r - b).abs(), (g - b).abs()),
        );
        if (cast > worst) {
          worst = cast;
        }
      }
    }
    return worst;
  }

  test('the illumination estimate is not fooled by per-channel noise', () {
    // Three independent per-channel maxima describe a colour no pixel in the
    // cell has. With noise and no shadow at all, the estimate must still come
    // out neutral.
    final img.Image page = img.Image(width: 240, height: 320);
    int state = 7;
    double next() {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state / 0x7fffffff;
    }

    for (int y = 0; y < 320; y++) {
      for (int x = 0; x < 240; x++) {
        final int nr = ((next() - 0.5) * 40).round();
        final int ng = ((next() - 0.5) * 40).round();
        final int nb = ((next() - 0.5) * 40).round();
        page.setPixelRgb(
          x,
          y,
          (190 + nr).clamp(0, 255),
          (190 + ng).clamp(0, 255),
          (190 + nb).clamp(0, 255),
        );
      }
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    final img.Image flat = ImagePipeline.flattenIllumination(page);

    expect(
      worstBlockCast(flat, 32),
      lessThan(5),
      reason: 'no region may come out tinted on neutral, evenly lit paper',
    );
    expect(after.width, 240);
  });

  test('sharpening cannot create a colour edge', () {
    // Detail is measured on luminance and added to all three channels. If R, G
    // and B were sharpened separately, a patch of colour would spread its
    // channels unevenly into the paper around it.
    final img.Image page = img.Image(width: 9, height: 9);
    img.fill(page, color: img.ColorRgb8(150, 150, 150));
    // Same luminance as the paper, quite different colour.
    page.setPixelRgb(4, 4, 170, 140, 140);

    final img.Image after = ImagePipeline.sharpen(page, asymmetric: true);
    final img.Pixel centre = after.getPixel(4, 4);
    final img.Pixel neighbour = after.getPixel(4, 3);

    expect(
      ((centre.r - centre.g) - 30).abs(),
      lessThan(4),
      reason: 'the patch keeps the chroma it had',
    );
    expect(centre.r - centre.g, greaterThan(26));
    expect(
      neighbour.r - neighbour.g,
      lessThan(3),
      reason: 'paper next to it stays grey',
    );
  });

  test('a bright coloured background does not tint the page edge', () {
    // The page lies on a gold envelope, which is as bright as the paper. The
    // illumination estimate must take its cue from the paper alone, or the
    // strip of envelope inside the crop turns the page edge orange.
    final img.Image page = img.Image(width: 240, height: 300);
    img.fill(page, color: img.ColorRgb8(203, 166, 88));
    img.fillRect(
      page,
      x1: 30,
      y1: 20,
      x2: 210,
      y2: 280,
      color: img.ColorRgb8(226, 222, 216),
    );
    for (int line = 0; line < 5; line++) {
      final int top = 50 + line * 40;
      img.fillRect(
        page,
        x1: 50,
        y1: top,
        x2: 190,
        y2: top + 10,
        color: img.ColorRgb8(60, 58, 56),
      );
    }

    final img.Image after = img.decodeImage(
      ImagePipeline.processPreset(img.encodeJpg(page), ScanPreset.auto),
    )!;

    // Paper just inside the page's left edge, and in the middle.
    final edge = meanIn(after, 34, 44, 30, 270);
    final middle = meanIn(after, 100, 140, 30, 270);

    expect((edge.r - edge.b).abs(), lessThan(10), reason: 'no warm fringe');
    expect((middle.r - middle.b).abs(), lessThan(10));
  });
}
