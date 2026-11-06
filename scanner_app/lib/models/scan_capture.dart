import 'crop_quad.dart';

/// One page as it comes out of the camera, before it is filed into a document.
///
/// [rawPath] is the capture, already turned upright and scaled to the size the
/// pipeline renders at, so every later render works from it instead of the
/// camera's much larger frame. [thumbPath] is a small enhanced preview of the
/// auto-cropped page, used for the corner stack in the scanner and for the
/// page list, so the user sees the actual result of each shot immediately.
class ScanCapture {
  const ScanCapture({
    required this.rawPath,
    required this.thumbPath,
    required this.quad,
  });

  final String rawPath;
  final String thumbPath;

  /// The page boundary detected on this capture, in normalized coordinates.
  final CropQuad quad;
}
