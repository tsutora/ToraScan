import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/screens/crop_geometry.dart';

void main() {
  // A 300 x 400 page drawn at the origin, so screen coordinates are easy to
  // reason about.
  const Rect frame = Rect.fromLTWH(0, 0, 300, 400);

  group('handles', () {
    test('there are eight of them, four corners then four edge mid-points', () {
      final List<Offset> handles = CropGeometry.normalizedHandles(
        CropQuad.full(),
      );

      expect(handles, hasLength(CropGeometry.handleCount));
      expect(handles.sublist(0, 4), <Offset>[
        const Offset(0, 0),
        const Offset(1, 0),
        const Offset(1, 1),
        const Offset(0, 1),
      ]);
      expect(handles.sublist(4), <Offset>[
        const Offset(0.5, 0), // top edge
        const Offset(1, 0.5), // right edge
        const Offset(0.5, 1), // bottom edge
        const Offset(0, 0.5), // left edge
      ]);
    });

    test('mid-edge handles follow a dragged corner', () {
      final CropQuad quad = CropQuad.fromValues(<double>[
        0.2,
        0.1,
        0.9,
        0.1,
        0.9,
        0.9,
        0.1,
        0.9,
      ]);
      final List<Offset> handles = CropGeometry.normalizedHandles(quad);

      // Top edge midpoint sits between the two top corners.
      expect(handles[4].dx, closeTo((0.2 + 0.9) / 2, 1e-9));
      expect(handles[4].dy, closeTo(0.1, 1e-9));
      // Bottom edge midpoint is unchanged by the top corners.
      expect(handles[6].dx, closeTo((0.9 + 0.1) / 2, 1e-9));
      expect(handles[6].dy, closeTo(0.9, 1e-9));
    });

    test('screen positions scale into the image rectangle', () {
      final List<Offset> handles = CropGeometry.screenHandles(
        CropQuad.full(),
        frame,
      );

      expect(handles[2], const Offset(300, 400));
      expect(handles[4], const Offset(150, 0));
      expect(handles[7], const Offset(0, 200));
    });

    test('each handle maps to the corners it is allowed to move', () {
      expect(CropGeometry.cornersForHandle(0), <int>[0]);
      expect(CropGeometry.cornersForHandle(3), <int>[3]);
      // Mid-edge handles move both corners of their edge.
      expect(CropGeometry.cornersForHandle(4), <int>[0, 1]);
      expect(CropGeometry.cornersForHandle(5), <int>[1, 2]);
      expect(CropGeometry.cornersForHandle(6), <int>[2, 3]);
      expect(CropGeometry.cornersForHandle(7), <int>[3, 0]);
    });
  });

  group('hit testing', () {
    test('every one of the eight handles is grabbable', () {
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
      final List<Offset> handles = CropGeometry.screenHandles(quad, frame);

      for (int i = 0; i < handles.length; i++) {
        expect(
          CropGeometry.hitTest(quad, frame, handles[i]),
          i,
          reason: 'handle $i should be hit at ${handles[i]}',
        );
      }
    });

    test('a finger away from every handle grabs nothing', () {
      expect(
        CropGeometry.hitTest(CropQuad.full(), frame, const Offset(150, 200)),
        isNull,
      );
    });

    test('a corner wins a tie against the crowded mid-edge handle', () {
      // A small page: corner 0 at (0,0), the top mid-point at (10,0). A tap at
      // (5,0) is exactly between them.
      const Rect small = Rect.fromLTWH(0, 0, 20, 20);

      expect(
        CropGeometry.hitTest(CropQuad.full(), small, const Offset(5, 0)),
        0,
      );
    });

    test('an empty rectangle cannot be hit', () {
      expect(
        CropGeometry.hitTest(CropQuad.full(), Rect.zero, Offset.zero),
        isNull,
      );
    });
  });

  group('dragging', () {
    test('a mid-edge drag slides that edge and leaves the opposite one', () {
      final CropQuad start = CropQuad.fromValues(<double>[
        0.1,
        0.2,
        0.9,
        0.2,
        0.9,
        0.8,
        0.1,
        0.8,
      ]);
      final List<Offset> handles = CropGeometry.screenHandles(start, frame);

      // Grab the bottom edge mid-point and drag it up by 40 px (0.1 of the
      // page height).
      final int handle = CropGeometry.hitTest(start, frame, handles[6])!;
      expect(handle, 6);

      final CropQuad moved = start.moveCorners(
        CropGeometry.cornersForHandle(handle),
        0,
        -40 / frame.height,
      );

      // Both bottom corners moved by the same amount: the edge slid.
      expect(moved.brY, closeTo(0.7, 1e-9));
      expect(moved.blY, closeTo(0.7, 1e-9));
      expect(moved.brY, closeTo(moved.blY, 1e-12));
      // The top edge and the horizontal positions are untouched.
      expect(moved.tlY, closeTo(0.2, 1e-9));
      expect(moved.trY, closeTo(0.2, 1e-9));
      expect(moved.blX, closeTo(0.1, 1e-9));
      expect(moved.brX, closeTo(0.9, 1e-9));
      // The edge stays horizontal, so no deformation.
      expect(moved.brY - moved.blY, 0);
    });

    test('a corner drag moves only that corner', () {
      final CropQuad start = CropQuad.fromValues(<double>[
        0.1,
        0.2,
        0.9,
        0.2,
        0.9,
        0.8,
        0.1,
        0.8,
      ]);
      final List<Offset> handles = CropGeometry.screenHandles(start, frame);
      final int handle = CropGeometry.hitTest(start, frame, handles[1])!;

      final CropQuad moved = start.moveCorners(
        CropGeometry.cornersForHandle(handle),
        0.05,
        0,
      );

      expect(moved.trX, closeTo(0.95, 1e-9));
      expect(moved.tlX, closeTo(0.1, 1e-9));
      expect(moved.brX, closeTo(0.9, 1e-9));
    });

    test('a fold-over quad is rejected as insane', () {
      // tl -> tr -> bl -> br: the outline crosses itself.
      final CropQuad folded = CropQuad.fromValues(<double>[
        0.1,
        0.1,
        0.9,
        0.1,
        0.1,
        0.9,
        0.9,
        0.9,
      ]);
      expect(CropGeometry.isSane(CropQuad.full()), isTrue);
      expect(CropGeometry.isSane(folded), isFalse);
    });
  });
}
