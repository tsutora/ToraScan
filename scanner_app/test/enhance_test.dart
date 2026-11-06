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
