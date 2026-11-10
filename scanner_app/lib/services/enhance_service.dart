import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/crop_quad.dart';
import '../models/scan_preset.dart';
import 'image_pipeline.dart';

/// Runs [ImagePipeline] off the UI thread and writes the result to disk.
///
/// Both the crop and the preset are applied to the *original* capture, so
/// switching presets or re-cropping a page never compounds compression or
/// sharpening artefacts.
class EnhanceService {
  const EnhanceService._();

  /// [maxEdge] caps the long side of the output. The scanner uses a small cap
  /// for the live thumbnails and the default for the pages that get saved.
  static Future<void> apply({
    required String sourcePath,
    required String outputPath,
    required ScanPreset preset,
    CropQuad? crop,
    int maxEdge = ImagePipeline.maxDimension,
    int quality = ImagePipeline.jpegQuality,
  }) {
    final CropQuad quad = crop ?? CropQuad.full();
    return compute(_enhanceIsolate, <Object?>[
      sourcePath,
      outputPath,
      preset.name,
      quad.values,
      quad.quarterTurns,
      maxEdge,
      quality,
    ]);
  }
}

Future<void> _enhanceIsolate(List<Object?> args) async {
  final String source = args[0]! as String;
  final String output = args[1]! as String;
  final ScanPreset preset = ScanPreset.fromName(args[2] as String?);
  final List<double> quadValues = (args[3]! as List<Object?>)
      .map((Object? e) => (e! as num).toDouble())
      .toList();
  final CropQuad crop = CropQuad.fromValues(
    quadValues,
    quarterTurns: args[4]! as int,
  );
  final int maxEdge = (args[5]! as int);
  final int quality = args.length > 6 ? (args[6]! as int) : ImagePipeline.jpegQuality;

  final Uint8List bytes = await File(source).readAsBytes();
  final Stopwatch watch = Stopwatch()..start();
  final Uint8List processed = ImagePipeline.processPreset(
    bytes,
    preset,
    crop: crop,
    maxEdge: maxEdge,
    quality: quality,
  );
  watch.stop();
  if (kDebugMode || kProfileMode) {
    debugPrint(
      'TORA  enhance ${preset.name} ${watch.elapsedMilliseconds} ms '
      '(${maxEdge}px)',
    );
  }

  final File file = File(output);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(processed, flush: true);
}
