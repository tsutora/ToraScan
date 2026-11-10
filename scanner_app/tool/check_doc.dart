// Measures how much colour the ENHANCED preset adds to paper, on a real capture
// from the library. Paper is identified in the *as scanned* render, so any
// chroma in the enhanced render is colour the pipeline invented.
//   dart run tool/check_doc.dart <original.jpg> <crop.json> [out.png]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

class _Block {
  _Block(this.x, this.y, this.r, this.g, this.b);

  final int x;
  final int y;
  final double r;
  final double g;
  final double b;

  double get luma => r * 0.299 + g * 0.587 + b * 0.114;
  double get chroma =>
      math.max((r - g).abs(), math.max((r - b).abs(), (g - b).abs()));
}

List<_Block> _blocks(img.Image image, int block) {
  final List<_Block> out = <_Block>[];
  for (int by = 0; by + block <= image.height; by += block) {
    for (int bx = 0; bx + block <= image.width; bx += block) {
      double r = 0;
      double g = 0;
      double b = 0;
      for (int y = by; y < by + block; y++) {
        for (int x = bx; x < bx + block; x++) {
          final img.Pixel p = image.getPixel(x, y);
          r += p.r;
          g += p.g;
          b += p.b;
        }
      }
      final int n = block * block;
      out.add(_Block(bx, by, r / n, g / n, b / n));
    }
  }
  return out;
}

void main(List<String> args) {
  final File source = File(args[0]);
  final CropQuad crop = CropQuad.fromJson(
    jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>,
  );
  final Uint8List bytes = source.readAsBytesSync();

  ImagePipeline.processPreset(bytes, ScanPreset.auto, crop: crop);

  final Stopwatch watch = Stopwatch()..start();
  final Uint8List autoBytes = ImagePipeline.processPreset(
    bytes,
    ScanPreset.auto,
    crop: crop,
  );
  watch.stop();
  final Uint8List rawBytes = ImagePipeline.processPreset(
    bytes,
    ScanPreset.none,
    crop: crop,
  );

  final img.Image raw = img.decodeImage(rawBytes)!;
  final img.Image enhanced = img.decodeImage(autoBytes)!;
  if (args.length > 2) {
    File(args[2]).writeAsBytesSync(autoBytes);
  }
  stdout.writeln(
    '${source.path}  ${enhanced.width}x${enhanced.height}  '
    'enhanced ${watch.elapsedMilliseconds} ms',
  );

  for (final int block in <int>[32, 64]) {
    final List<_Block> rawBlocks = _blocks(raw, block);
    final List<_Block> paper = _blocks(enhanced, block)
        .where((_Block b) {
          final _Block before = rawBlocks.firstWhere(
            (_Block r) => r.x == b.x && r.y == b.y,
          );
          return before.luma > 110 && before.chroma < 8;
        })
        .toList();

    if (paper.isEmpty) {
      stdout.writeln('  $block px: no paper blocks');
      continue;
    }
    final List<double> chroma = paper.map((_Block b) => b.chroma).toList()
      ..sort();
    final double mean =
        chroma.reduce((double a, double b) => a + b) / chroma.length;
    final double p99 = chroma[(chroma.length * 0.99).floor().clamp(
      0,
      chroma.length - 1,
    )];
    final _Block worst = paper.reduce(
      (_Block a, _Block b) => a.chroma >= b.chroma ? a : b,
    );
    final int over = chroma.where((double c) => c > 8).length;
    stdout.writeln(
      '  $block px  paper ${paper.length} blocks  '
      'mean ${mean.toStringAsFixed(1)}  p99 ${p99.toStringAsFixed(1)}  '
      '>8 ${(over * 100 / chroma.length).toStringAsFixed(1)}%  '
      'worst ${worst.chroma.toStringAsFixed(1)} at (${worst.x},${worst.y}) '
      '[${worst.r.toStringAsFixed(0)},${worst.g.toStringAsFixed(0)},'
      '${worst.b.toStringAsFixed(0)}]',
    );
  }
}
