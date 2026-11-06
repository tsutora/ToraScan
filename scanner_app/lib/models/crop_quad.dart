/// A quadrilateral in normalized image coordinates, used by the 8-point crop
/// screen.
///
/// Coordinates are fractions of the image (0..1) measured *after* the capture
/// has been rotated upright. That makes a quad independent of the resolution a
/// page happens to be processed at, so a crop can be re-applied later to the
/// untouched original without any loss of quality.
///
/// Corners run clockwise from the top-left:
/// 0 = top-left, 1 = top-right, 2 = bottom-right, 3 = bottom-left.
///
/// The quad also carries [quarterTurns]: the page can be turned in the crop
/// screen, and the rotation is baked in when the page is rendered, so it stays
/// attached to the crop that was drawn on the turned image.
class CropQuad {
  const CropQuad({
    required this.tlX,
    required this.tlY,
    required this.trX,
    required this.trY,
    required this.brX,
    required this.brY,
    required this.blX,
    required this.blY,
    this.quarterTurns = 0,
  });

  /// The whole frame: the page is used exactly as the scanner returned it.
  factory CropQuad.full() => const CropQuad(
    tlX: 0,
    tlY: 0,
    trX: 1,
    trY: 0,
    brX: 1,
    brY: 1,
    blX: 0,
    blY: 1,
  );

  factory CropQuad.fromValues(List<double> v, {int quarterTurns = 0}) {
    if (v.length != 8) {
      throw ArgumentError.value(v, 'v', 'A quad needs exactly 8 values');
    }
    return CropQuad(
      tlX: v[0],
      tlY: v[1],
      trX: v[2],
      trY: v[3],
      brX: v[4],
      brY: v[5],
      blX: v[6],
      blY: v[7],
      quarterTurns: quarterTurns % 4,
    );
  }

  final double tlX;
  final double tlY;
  final double trX;
  final double trY;
  final double brX;
  final double brY;
  final double blX;
  final double blY;

  /// Clockwise quarter turns applied to the page before the crop is taken.
  /// 0 = as captured, 1 = turned right, 2 = upside down, 3 = turned left.
  final int quarterTurns;

  List<double> get values => <double>[tlX, tlY, trX, trY, brX, brY, blX, blY];

  double x(int corner) => switch (corner) {
    0 => tlX,
    1 => trX,
    2 => brX,
    _ => blX,
  };

  double y(int corner) => switch (corner) {
    0 => tlY,
    1 => trY,
    2 => brY,
    _ => blY,
  };

  /// True when the quad covers the whole frame, so no resampling is needed.
  bool get isFull =>
      tlX <= 0.0005 &&
      tlY <= 0.0005 &&
      trX >= 0.9995 &&
      trY <= 0.0005 &&
      brX >= 0.9995 &&
      brY >= 0.9995 &&
      blX <= 0.0005 &&
      blY >= 0.9995;

  /// The same page, turned a quarter turn to the right.
  ///
  /// The corners are rotated with the image and re-indexed so corner 0 is still
  /// the top-left of the *turned* page: old bottom-left becomes the new
  /// top-left, and so on. That keeps the crop glued to the same paper.
  CropQuad rotatedCw() => CropQuad(
    tlX: 1 - blY,
    tlY: blX,
    trX: 1 - tlY,
    trY: tlX,
    brX: 1 - trY,
    brY: trX,
    blX: 1 - brY,
    blY: brX,
    quarterTurns: (quarterTurns + 1) % 4,
  );

  /// The same page, turned a quarter turn to the left.
  CropQuad rotatedCcw() => CropQuad(
    tlX: trY,
    tlY: 1 - trX,
    trX: brY,
    trY: 1 - brX,
    brX: blY,
    brY: 1 - blX,
    blX: tlY,
    blY: 1 - tlX,
    quarterTurns: (quarterTurns + 3) % 4,
  );

  /// Moves [corners] together by the same delta, clamped so none of them leaves
  /// the frame.
  ///
  /// This is what the mid-edge handles use: both corners of the edge must move
  /// by an identical amount, otherwise the edge deforms instead of sliding.
  CropQuad moveCorners(List<int> corners, double dx, double dy) {
    if (corners.isEmpty) {
      return this;
    }

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final int corner in corners) {
      final double px = x(corner);
      final double py = y(corner);
      if (px < minX) {
        minX = px;
      }
      if (px > maxX) {
        maxX = px;
      }
      if (py < minY) {
        minY = py;
      }
      if (py > maxY) {
        maxY = py;
      }
    }

    final double cdx = dx.clamp(-minX, 1 - maxX).toDouble();
    final double cdy = dy.clamp(-minY, 1 - maxY).toDouble();

    final List<double> v = values;
    for (final int corner in corners) {
      v[corner * 2] = v[corner * 2] + cdx;
      v[corner * 2 + 1] = v[corner * 2 + 1] + cdy;
    }
    return CropQuad.fromValues(v, quarterTurns: quarterTurns);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': values,
    'r': quarterTurns,
  };

  factory CropQuad.fromJson(Map<String, dynamic>? json) {
    final List<dynamic>? raw = json?['v'] as List<dynamic>?;
    if (raw == null || raw.length != 8) {
      return CropQuad.full();
    }
    return CropQuad.fromValues(
      raw.map((dynamic e) => (e as num).toDouble()).toList(),
      // Documents written before rotation existed simply have no 'r'.
      quarterTurns: (json?['r'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'CropQuad(${values.join(', ')})';
}
