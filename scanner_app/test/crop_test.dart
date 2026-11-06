import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

void main() {
  group('CropQuad', () {
    test('the full quad covers the frame', () {
      expect(CropQuad.full().isFull, isTrue);
    });

    test('an inset quad is not full', () {
      final CropQuad quad = CropQuad.fromValues(<double>[
        0.1,
        0.1,
        0.9,
        0.1,
        0.9,
        0.9,
        0.1,
        0.9,
      ]);
      expect(quad.isFull, isFalse);
    });

    test('a mid-edge drag moves both corners of that edge', () {
      final CropQuad moved = CropQuad.full().moveCorners(<int>[0, 1], 0, 0.1);

      expect(moved.tlY, closeTo(0.1, 1e-9));
      expect(moved.trY, closeTo(0.1, 1e-9));
      // The opposite edge must not move.
      expect(moved.brY, closeTo(1, 1e-9));
      expect(moved.blY, closeTo(1, 1e-9));
    });

    test('a corner cannot be dragged outside the frame', () {
      final CropQuad moved = CropQuad.full().moveCorners(<int>[0], -0.5, -0.5);

      expect(moved.tlX, 0);
      expect(moved.tlY, 0);
    });

    test('a shared drag is clamped for every corner it touches', () {
      final CropQuad start = CropQuad.fromValues(<double>[
        0.1,
        0.1,
        0.9,
        0.1,
        0.6,
        0.9,
        0.5,
        0.9,
      ]);
      final CropQuad moved = start.moveCorners(<int>[2, 3], 0.5, 0.5);

      // dx is limited by the right-most corner, and both move by that same
      // amount so the bottom edge slides instead of deforming.
      expect(moved.brX, closeTo(1.0, 1e-9));
      expect(moved.blX, closeTo(0.9, 1e-9));
      expect(moved.brY, closeTo(1.0, 1e-9));
      expect(moved.blY, closeTo(1.0, 1e-9));
    });

    test('quads survive a JSON round trip', () {
      final CropQuad quad = CropQuad.fromValues(<double>[
        0.1,
        0.2,
        0.9,
        0.15,
        0.88,
        0.9,
        0.12,
        0.85,
      ]);
      final CropQuad back = CropQuad.fromJson(
        jsonDecode(jsonEncode(quad.toJson())) as Map<String, dynamic>,
      );

      expect(back.values, quad.values);
    });

    test('a missing JSON quad falls back to the full frame', () {
      expect(CropQuad.fromJson(null).isFull, isTrue);
      expect(
        CropQuad.fromJson(<String, dynamic>{
          'v': <double>[1, 2],
        }).isFull,
        isTrue,
      );
    });

    test('turning right moves the corners with the page', () {
      final CropQuad quad = CropQuad.fromValues(<double>[
        0.1,
        0.2,
        0.9,
        0.2,
        0.9,
        0.8,
        0.1,
        0.8,
      ]);
      final CropQuad turned = quad.rotatedCw();

      // Old bottom-left becomes the new top-left: (x, y) -> (1 - y, x).
      expect(turned.tlX, closeTo(0.2, 1e-9));
      expect(turned.tlY, closeTo(0.1, 1e-9));
      // Old top-left becomes the new top-right.
      expect(turned.trX, closeTo(0.8, 1e-9));
      expect(turned.trY, closeTo(0.1, 1e-9));
      expect(turned.brX, closeTo(0.8, 1e-9));
      expect(turned.brY, closeTo(0.9, 1e-9));
      expect(turned.blX, closeTo(0.2, 1e-9));
      expect(turned.blY, closeTo(0.9, 1e-9));
      expect(turned.quarterTurns, 1);
    });

    test('turning left is the inverse of turning right', () {
      final CropQuad quad = CropQuad.fromValues(<double>[
        0.1,
        0.2,
        0.9,
        0.2,
        0.9,
        0.8,
        0.1,
        0.8,
      ]);
      final CropQuad back = quad.rotatedCw().rotatedCcw();

      for (int i = 0; i < 8; i++) {
        expect(back.values[i], closeTo(quad.values[i], 1e-9));
      }
      expect(back.quarterTurns, 0);
    });

    test('four turns come back to the same page', () {
      final CropQuad quad = CropQuad.fromValues(<double>[
        0.12,
        0.2,
        0.91,
        0.17,
        0.86,
        0.88,
        0.1,
        0.82,
      ]);
      CropQuad turned = quad;
      for (int i = 0; i < 4; i++) {
        turned = turned.rotatedCw();
      }

      for (int i = 0; i < 8; i++) {
        expect(turned.values[i], closeTo(quad.values[i], 1e-9));
      }
      expect(turned.quarterTurns, 0);
    });

    test('rotation survives a JSON round trip', () {
      final CropQuad quad = CropQuad.full().rotatedCw().rotatedCw();
      final CropQuad back = CropQuad.fromJson(
        jsonDecode(jsonEncode(quad.toJson())) as Map<String, dynamic>,
      );

      expect(back.quarterTurns, 2);
      expect(back.values, quad.values);
    });

    test('a drag keeps the rotation it was drawn on', () {
      final CropQuad turned = CropQuad.full().rotatedCw();
      final CropQuad moved = turned.moveCorners(<int>[0], 0.1, 0.1);

      expect(moved.quarterTurns, 1);
    });
  });

  group('cropPerspective', () {
    test('leaves a full-frame quad untouched', () {
      final img.Image source = img.Image(width: 40, height: 30);
      img.fill(source, color: img.ColorRgb8(120, 120, 120));

      final img.Image out = ImagePipeline.cropPerspective(
        source,
        CropQuad.full(),
      );

      expect(out.width, 40);
      expect(out.height, 30);
    });

    test('extracts the requested region', () {
      final img.Image source = img.Image(width: 100, height: 100);
      img.fill(source, color: img.ColorRgb8(20, 20, 20));
      img.fillRect(
        source,
        x1: 0,
        y1: 0,
        x2: 49,
        y2: 49,
        color: img.ColorRgb8(240, 240, 240),
      );

      final img.Image out = ImagePipeline.cropPerspective(
        source,
        CropQuad.fromValues(<double>[0, 0, 0.5, 0, 0.5, 0.5, 0, 0.5]),
      );

      expect(out.width, closeTo(50, 1));
      expect(out.height, closeTo(50, 1));
      expect(out.getPixel(5, 5).r, greaterThan(200));
    });

    test('rectifies a skewed quad instead of failing', () {
      final img.Image source = img.Image(width: 120, height: 120);
      img.fill(source, color: img.ColorRgb8(200, 200, 200));

      final img.Image out = ImagePipeline.cropPerspective(
        source,
        CropQuad.fromValues(<double>[
          0.1,
          0.05,
          0.95,
          0.12,
          0.9,
          0.95,
          0.08,
          0.88,
        ]),
      );

      expect(out.width, greaterThan(50));
      expect(out.height, greaterThan(50));
      expect(out.getPixel(out.width ~/ 2, out.height ~/ 2).r, greaterThan(150));
    });
  });

  test('processPreset applies the crop before encoding', () {
    final img.Image page = img.Image(width: 200, height: 200);
    img.fill(page, color: img.ColorRgb8(240, 240, 240));

    final Uint8List out = ImagePipeline.processPreset(
      img.encodeJpg(page),
      ScanPreset.none,
      crop: CropQuad.fromValues(<double>[
        0.25,
        0.25,
        0.75,
        0.25,
        0.75,
        0.75,
        0.25,
        0.75,
      ]),
    );

    final img.Image decoded = img.decodeImage(out)!;
    expect(decoded.width, closeTo(100, 2));
    expect(decoded.height, closeTo(100, 2));
  });

  test('processPreset bakes in a quarter turn', () {
    final img.Image page = img.Image(width: 200, height: 100);
    img.fill(page, color: img.ColorRgb8(240, 240, 240));
    // A dark bar along the left edge, so the turn is visible in the pixels.
    img.fillRect(
      page,
      x1: 0,
      y1: 0,
      x2: 19,
      y2: 99,
      color: img.ColorRgb8(10, 10, 10),
    );

    final Uint8List out = ImagePipeline.processPreset(
      img.encodeJpg(page),
      ScanPreset.none,
      crop: CropQuad.full().rotatedCw(),
    );

    final img.Image decoded = img.decodeImage(out)!;
    // 200x100 turned right is 100x200.
    expect(decoded.width, closeTo(100, 2));
    expect(decoded.height, closeTo(200, 2));
    // The left bar ends up along the top edge.
    expect(decoded.getPixel(50, 3).r, lessThan(60));
    expect(decoded.getPixel(50, 195).r, greaterThan(180));
  });
}
