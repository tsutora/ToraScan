// Times each enhancement stage several times on one real capture, after a
// warm-up, so JIT noise does not dominate.
//   dart run tool/bench_stages.dart [image] [repeats]
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

void main(List<String> args) {
  final File f = File(args.isEmpty ? 'build/samples/orig_2.jpg' : args.first);
  final int repeats = args.length > 1 ? int.parse(args[1]) : 3;

  img.Image base = img.bakeOrientation(img.decodeImage(f.readAsBytesSync())!);
  final int longest = math.max(base.width, base.height);
  if (longest > ImagePipeline.maxDimension) {
    base = base.width >= base.height
        ? img.copyResize(base, width: ImagePipeline.maxDimension)
        : img.copyResize(base, height: ImagePipeline.maxDimension);
  }
  final Uint8List bytes = f.readAsBytesSync();
  stdout.writeln('${f.path}  ${base.width}x${base.height}  repeats $repeats');

  void time(String label, void Function() body) {
    final List<int> runs = <int>[];
    for (int i = 0; i < repeats; i++) {
      final Stopwatch watch = Stopwatch()..start();
      body();
      watch.stop();
      runs.add(watch.elapsedMilliseconds);
    }
    stdout.writeln('  $label  ${runs.join(' / ')} ms');
  }

  // Warm-up: run everything once so compilation is not counted.
  ImagePipeline.processPreset(bytes, ScanPreset.auto);

  img.Image flat = base;
  img.Image tone = base;
  // Calibration: a bare pass over the same buffer, to tell "slow code" apart
  // from "slow machine".
  time('rawpass ', () {
    final Uint8List b = base.toUint8List();
    final int stride = base.rowStride;
    int acc = 0;
    for (int y = 0; y < base.height; y++) {
      final int row = y * stride;
      for (int x = 0; x < base.width; x++) {
        final int i = row + x * 3;
        acc += b[i] + b[i + 1] + b[i + 2];
      }
    }
    if (acc < 0) {
      stdout.write('');
    }
  });
  time('flatten ', () => flat = ImagePipeline.flattenIllumination(base));
  time('tone    ', () => tone = ImagePipeline.toneMap(flat, whitePoint: 236));
  time('tone+sat', () {
    tone = ImagePipeline.toneMap(flat, whitePoint: 236, saturation: 1.5);
  });
  time('sharpen ', () => ImagePipeline.sharpen(tone, asymmetric: true));
  time('preset  ', () {
    ImagePipeline.processPreset(bytes, ScanPreset.auto, crop: null);
  });
}
