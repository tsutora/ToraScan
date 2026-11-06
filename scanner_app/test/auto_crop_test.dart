import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/services/auto_crop.dart';

/// Builds a dark desk with a bright sheet on it, so the detector has something
/// it can actually find. Coordinates are in the synthetic image's pixels.
Uint8List _pageOnDesk({
  int width = 240,
  int height = 240,
  int left = 50,
  int top = 40,
  int right = 200,
  int bottom = 210,
}) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(38, 36, 34));
  img.fillRect(
    image,
    x1: left,
    y1: top,
    x2: right,
    y2: bottom,
    color: img.ColorRgb8(236, 233, 228),
  );
  // A few dark lines stand in for text: the blur in the detector should close
  // them up again rather than splitting the page.
  for (int y = top + 16; y < bottom - 12; y += 14) {
    img.fillRect(
      image,
      x1: left + 14,
      y1: y,
      x2: right - 14,
      y2: y + 3,
      color: img.ColorRgb8(30, 30, 30),
    );
  }
  return img.encodePng(image);
}

void main() {
  group('AutoCrop', () {
    test('finds the bright sheet on a dark desk', () {
      final CropQuad quad = AutoCrop.detectBytes(_pageOnDesk());

      expect(quad.isFull, isFalse, reason: 'a page was clearly visible');

      // Normalized against (w - 1), so 240 px puts the sheet near these
      // fractions; the tolerance leaves room for the blur and the hull.
      expect(quad.tlX, closeTo(50 / 239, 0.03));
      expect(quad.tlY, closeTo(40 / 239, 0.03));
      expect(quad.trX, closeTo(200 / 239, 0.03));
      expect(quad.trY, closeTo(40 / 239, 0.03));
      expect(quad.brX, closeTo(200 / 239, 0.03));
      expect(quad.brY, closeTo(210 / 239, 0.03));
      expect(quad.blX, closeTo(50 / 239, 0.03));
      expect(quad.blY, closeTo(210 / 239, 0.03));
    });

    test('finds a coloured page on a dark desk', () {
      // A pink form is not "bright and neutral", so the paperness map cannot
      // see it. The brightness map has to find it, and the edge score has to
      // prefer it over the dark desk.
      final img.Image scene = img.Image(width: 260, height: 340);
      img.fill(scene, color: img.ColorRgb8(38, 34, 32));
      img.fillRect(
        scene,
        x1: 40,
        y1: 30,
        x2: 220,
        y2: 310,
        color: img.ColorRgb8(240, 190, 204),
      );
      for (int y = 50; y < 290; y += 20) {
        img.fillRect(
          scene,
          x1: 60,
          y1: y,
          x2: 200,
          y2: y + 6,
          color: img.ColorRgb8(48, 46, 50),
        );
      }

      final CropQuad quad = AutoCrop.detectBytes(img.encodePng(scene));

      expect(quad.isFull, isFalse, reason: 'the pink page is clearly visible');
      expect(quad.tlX, closeTo(40 / 259, 0.05));
      expect(quad.tlY, closeTo(30 / 339, 0.05));
      expect(quad.brX, closeTo(220 / 259, 0.05));
      expect(quad.brY, closeTo(310 / 339, 0.05));
    });

    test('detects a page that runs off two edges of the frame', () {
      // A close-up shot where the sheet reaches the top and left edges. There
      // is no desk beyond those borders, so the edge score must judge the two
      // borders it can see instead of averaging in the frame boundary.
      final img.Image scene = img.Image(width: 260, height: 340);
      img.fill(scene, color: img.ColorRgb8(36, 33, 30));
      img.fillRect(
        scene,
        x1: 0,
        y1: 0,
        x2: 214,
        y2: 324,
        color: img.ColorRgb8(238, 235, 230),
      );
      for (int y = 24; y < 300; y += 22) {
        img.fillRect(
          scene,
          x1: 24,
          y1: y,
          x2: 190,
          y2: y + 6,
          color: img.ColorRgb8(48, 46, 50),
        );
      }

      final CropQuad quad = AutoCrop.detectBytes(img.encodePng(scene));

      expect(quad.isFull, isFalse);
      expect(quad.brX, closeTo(214 / 259, 0.06));
      expect(quad.brY, closeTo(324 / 339, 0.06));
    });

    test('returns the full frame when there is no page', () {
      final img.Image dark = img.Image(width: 200, height: 260);
      img.fill(dark, color: img.ColorRgb8(20, 20, 22));

      final CropQuad quad = AutoCrop.detectBytes(img.encodePng(dark));

      expect(quad.isFull, isTrue);
    });

    test('ignores a bright coloured envelope under the page', () {
      // A white sheet on a gold manila envelope. The envelope is as bright as
      // the paper, so a luminance-only detector swallows it and crops to the
      // whole frame; paper is the bright thing that is also colourless.
      final img.Image scene = img.Image(width: 260, height: 340);
      img.fill(scene, color: img.ColorRgb8(203, 166, 88));
      img.fillRect(
        scene,
        x1: 40,
        y1: 30,
        x2: 220,
        y2: 310,
        color: img.ColorRgb8(232, 229, 224),
      );
      for (int y = 50; y < 290; y += 20) {
        img.fillRect(
          scene,
          x1: 60,
          y1: y,
          x2: 200,
          y2: y + 6,
          color: img.ColorRgb8(40, 40, 42),
        );
      }

      final CropQuad quad = AutoCrop.detectBytes(img.encodePng(scene));

      expect(quad.isFull, isFalse, reason: 'the page is clearly visible');
      expect(quad.tlX, closeTo(40 / 259, 0.04));
      expect(quad.tlY, closeTo(30 / 339, 0.04));
      expect(quad.brX, closeTo(220 / 259, 0.04));
      expect(quad.brY, closeTo(310 / 339, 0.04));
    });

    test('finds the page on a bright neutral desk', () {
      // A white sheet on light grey floor tiles: both are neutral, so the
      // threshold has to be raised until the quad lands on the page's border
      // rather than on the tiles.
      final img.Image scene = img.Image(width: 260, height: 340);
      img.fill(scene, color: img.ColorRgb8(150, 150, 148));
      img.fillRect(
        scene,
        x1: 40,
        y1: 30,
        x2: 220,
        y2: 310,
        color: img.ColorRgb8(238, 236, 232),
      );

      final CropQuad quad = AutoCrop.detectBytes(img.encodePng(scene));

      expect(quad.isFull, isFalse);
      expect(quad.tlX, closeTo(40 / 259, 0.05));
      expect(quad.tlY, closeTo(30 / 339, 0.05));
      expect(quad.brX, closeTo(220 / 259, 0.05));
      expect(quad.brY, closeTo(310 / 339, 0.05));
    });

    test('refuses a frame that is bright edge to edge', () {
      // A white sheet on a white desk has no boundary to find; cropping to the
      // detected "blob" would be the whole frame, so the detector should bail
      // out instead of inventing an inset.
      final img.Image white = img.Image(width: 200, height: 260);
      img.fill(white, color: img.ColorRgb8(255, 255, 255));

      final CropQuad quad = AutoCrop.detectBytes(img.encodePng(white));

      expect(quad.isFull, isTrue);
    });

    test('survives bytes that are not an image', () {
      final CropQuad quad = AutoCrop.detectBytes(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      expect(quad.isFull, isTrue);
    });
  });
}
