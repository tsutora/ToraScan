import 'package:flutter/painting.dart';

import '../models/crop_quad.dart';

/// Pure geometry for the eight-point crop editor.
///
/// Kept out of the screen widget so the handle layout and the hit-testing rules
/// can be tested directly, without pumping a widget tree or decoding an image.
///
/// Handle order: 0-3 are the corners (top-left, top-right, bottom-right,
/// bottom-left); 4-7 are the mid-points of the edges between corner `i` and
/// corner `i + 1`.
class CropGeometry {
  const CropGeometry._();

  static const int cornerCount = 4;
  static const int handleCount = 8;

  /// How close a finger has to be to a handle, in logical pixels.
  static const double hitRadius = 34;

  /// The eight handles in normalized (0..1) image coordinates.
  static List<Offset> normalizedHandles(CropQuad quad) {
    final List<Offset> corners = <Offset>[
      for (int i = 0; i < cornerCount; i++) Offset(quad.x(i), quad.y(i)),
    ];
    return <Offset>[
      ...corners,
      for (int i = 0; i < cornerCount; i++)
        Offset.lerp(corners[i], corners[(i + 1) % cornerCount], 0.5)!,
    ];
  }

  /// The same eight handles mapped onto [imageRect] on screen.
  static List<Offset> screenHandles(CropQuad quad, Rect imageRect) {
    return <Offset>[
      for (final Offset point in normalizedHandles(quad))
        Offset(
          imageRect.left + point.dx * imageRect.width,
          imageRect.top + point.dy * imageRect.height,
        ),
    ];
  }

  /// Which corners a handle moves.
  ///
  /// A corner handle moves one corner; a mid-edge handle moves *both* corners of
  /// its edge by the same delta, which slides the edge instead of deforming it.
  static List<int> cornersForHandle(int handle) {
    if (handle < cornerCount) {
      return <int>[handle];
    }
    final int edge = handle - cornerCount;
    return <int>[edge, (edge + 1) % cornerCount];
  }

  /// The handle under [point], or null when the finger missed every handle.
  ///
  /// Corners are earlier in the list and the comparison is strict, so a corner
  /// wins a tie — it stays grabbable even on a small page where the mid-edge
  /// handles crowd it.
  static int? hitTest(
    CropQuad quad,
    Rect imageRect,
    Offset point, {
    double radius = hitRadius,
  }) {
    if (imageRect.isEmpty) {
      return null;
    }

    final List<Offset> handles = screenHandles(quad, imageRect);
    int? best;
    double bestDistance = radius;

    for (int i = 0; i < handles.length; i++) {
      final double distance = (handles[i] - point).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  /// Rejects a quad that has folded over itself, which would make the
  /// perspective transform produce garbage.
  static bool isSane(CropQuad quad) {
    double area = 0;
    for (int i = 0; i < cornerCount; i++) {
      final int j = (i + 1) % cornerCount;
      area += quad.x(i) * quad.y(j) - quad.x(j) * quad.y(i);
    }
    return area > 0.01;
  }
}
