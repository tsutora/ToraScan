import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/crop_quad.dart';
import '../models/scan_capture.dart';
import 'auto_crop.dart';
import 'image_pipeline.dart';

/// Turns one camera frame into a [ScanCapture] in a single pass.
///
/// The capture is decoded exactly once, and everything downstream reuses that
/// decode: the page boundary is found, the small preview is rectified and
/// enhanced, and the frame is normalised to the size the pipeline actually
/// renders at. That last step matters: phones happily shoot 12 MP, while a
/// page is rendered at 2400 px, so storing the camera's frame unchanged would
/// mean decoding three times more pixels on every later render, and keeping
/// three times the bytes in the library.
class ScanProcessor {
  const ScanProcessor._();

  /// Long side of the preview shown in the corner stack.
  static const int thumbEdge = 420;

  /// Quality of the normalised capture. It is the source every later render is
  /// built from, so it sits well above the rendered page: at 95 the extra
  /// generation is not visible, even after the page is re-encoded at 88.
  static const int originalQuality = 95;

  static Future<ScanCapture> capture({
    required String rawPath,
    required String thumbPath,
  }) {
    return prepare(sourcePath: rawPath, rawPath: rawPath, thumbPath: thumbPath);
  }

  /// Turns any image on disk into a [ScanCapture].
  ///
  /// [sourcePath] may differ from [rawPath] — a gallery photo or a page
  /// rasterised from a PDF — in which case the normalised page is written to
  /// [rawPath] and the source is left alone. [detectCrop] is off for a PDF
  /// page: the page *is* the paper, so looking for a page boundary inside it
  /// would only risk clipping its margins. The crop screen still lets the user
  /// adjust the full frame.
  static Future<ScanCapture> prepare({
    required String sourcePath,
    required String rawPath,
    required String thumbPath,
    bool detectCrop = true,
  }) {
    return compute(_captureIsolate, <Object?>[
      sourcePath,
      rawPath,
      thumbPath,
      detectCrop,
    ]);
  }
}

/// Runs in its own isolate so the viewfinder never stalls on a 12 MP decode.
///
/// The phase timings below are deliberate: a phone camera hands us roughly
/// three times the pixels the library keeps, so this function is where a slow
/// build shows up first. They cost nothing in a release build.
Future<ScanCapture> _captureIsolate(List<Object?> args) async {
  final String sourcePath = args[0]! as String;
  final String rawPath = args[1]! as String;
  final String thumbPath = args[2]! as String;
  final bool detectCrop = args[3]! as bool;
  final Stopwatch watch = Stopwatch()..start();

  final Uint8List bytes = await File(sourcePath).readAsBytes();
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    if (sourcePath != rawPath) {
      try {
        await File(sourcePath).copy(rawPath);
      } catch (_) {
        // The caller still gets a capture; the thumbnail simply stays empty.
      }
    }
    return ScanCapture(rawPath: rawPath, thumbPath: '', quad: CropQuad.full());
  }
  if (kDebugMode || kProfileMode) {
    debugPrint(
      'TORA  decode ${watch.elapsedMilliseconds} ms '
      '(${decoded.width}x${decoded.height})',
    );
  }

  img.Image page = img.bakeOrientation(decoded);

  // Normalise oversized captures once, in place. The file the scanner copied
  // into the cache is ours, so it is replaced with the page-sized version. An
  // imported source is always written out, because it may be a PNG or a format
  // the rest of the pipeline should not have to think about.
  final int longest = page.width > page.height ? page.width : page.height;
  final bool oversized = longest > ImagePipeline.maxDimension;
  if (oversized) {
    page = page.width >= page.height
        ? img.copyResize(
            page,
            width: ImagePipeline.maxDimension,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            page,
            height: ImagePipeline.maxDimension,
            interpolation: img.Interpolation.average,
          );
    if (kDebugMode || kProfileMode) {
      debugPrint('TORA  normalise ${watch.elapsedMilliseconds} ms');
    }
  }
  if (oversized || sourcePath != rawPath) {
    await File(rawPath).writeAsBytes(
      img.encodeJpg(page, quality: ScanProcessor.originalQuality),
      flush: true,
    );
  }

  final CropQuad quad = detectCrop
      ? AutoCrop.detectImage(page)
      : CropQuad.full();
  if (kDebugMode || kProfileMode) {
    debugPrint('TORA  detect ${watch.elapsedMilliseconds} ms');
  }

  img.Image small = page;
  final int smallLongest = page.width > page.height ? page.width : page.height;
  if (smallLongest > ScanProcessor.thumbEdge) {
    small = page.width >= page.height
        ? img.copyResize(
            page,
            width: ScanProcessor.thumbEdge,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            page,
            height: ScanProcessor.thumbEdge,
            interpolation: img.Interpolation.average,
          );
  }

  final img.Image cropped = quad.isFull
      ? small
      : ImagePipeline.cropPerspective(small, quad);
  final Uint8List preview = img.encodeJpg(
    ImagePipeline.auto(cropped),
    quality: 84,
  );

  final File thumb = File(thumbPath);
  await thumb.parent.create(recursive: true);
  await thumb.writeAsBytes(preview, flush: true);
  if (kDebugMode || kProfileMode) {
    debugPrint('TORA  preview ${watch.elapsedMilliseconds} ms');
  }

  return ScanCapture(rawPath: rawPath, thumbPath: thumbPath, quad: quad);
}
