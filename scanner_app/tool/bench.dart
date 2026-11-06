// Measures the enhancement stages on real captures, without a device.
//
//   dart run tool/bench.dart [image ...]
//
// Defaults to build/samples/*.jpg. Writes build/bench/<name>-auto.jpg (and a
// PNG next to it for exact inspection) and prints per-stage timings.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

void main(List<String> args) {
  final List<File> samples = <File>[];
  if (args.isEmpty) {
    final Directory dir = Directory('build/samples');
    if (dir.existsSync()) {
      for (final FileSystemEntity entity in dir.listSync()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          samples.add(entity);
        }
      }
    }
  } else {
    for (final String path in args) {
      samples.add(File(path));
    }
  }

  final Directory out = Directory('build/bench')..createSync(recursive: true);
  for (final File sample in samples) {
    final String name = sample.uri.pathSegments.last.split('.').first;
    final Uint8List bytes = sample.readAsBytesSync();

    final Stopwatch decodeWatch = Stopwatch()..start();
    img.Image image = img.bakeOrientation(img.decodeImage(bytes)!);
    final int longest = image.width > image.height
        ? image.width
        : image.height;
    if (longest > ImagePipeline.maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: ImagePipeline.maxDimension,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: ImagePipeline.maxDimension,
              interpolation: img.Interpolation.average,
            );
    }
    decodeWatch.stop();

    final Stopwatch flatWatch = Stopwatch()..start();
    final img.Image flat = ImagePipeline.flattenIllumination(image);
    flatWatch.stop();

    final Stopwatch toneWatch = Stopwatch()..start();
    final img.Image tone = ImagePipeline.toneMap(flat, whitePoint: 236);
    toneWatch.stop();

    final Stopwatch sharpWatch = Stopwatch()..start();
    final img.Image sharp = ImagePipeline.sharpen(tone);
    sharpWatch.stop();

    final Stopwatch totalWatch = Stopwatch()..start();
    final Uint8List jpeg = ImagePipeline.processPreset(
      bytes,
      ScanPreset.auto,
      crop: CropQuad.full(),
    );
    totalWatch.stop();

    File('${out.path}/$name-auto.jpg').writeAsBytesSync(jpeg);
    File('${out.path}/$name-auto.png').writeAsBytesSync(img.encodePng(sharp));

    stdout.writeln(
      '$name  ${image.width}x${image.height}  '
      'decode ${decodeWatch.elapsedMilliseconds} ms  '
      'flatten ${flatWatch.elapsedMilliseconds} ms  '
      'tone ${toneWatch.elapsedMilliseconds} ms  '
      'sharpen ${sharpWatch.elapsedMilliseconds} ms  '
      'total ${totalWatch.elapsedMilliseconds} ms  '
      '${(jpeg.length / 1024).round()} KB',
    );
  }
}
