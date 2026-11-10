// Renders one library document through the ENHANCED pipeline on the host, so a
// real capture can be inspected without the phone's UI.
//   dart run tool/render_doc.dart <original.jpg> <out.png> [crop.json]
// The optional crop.json is the document's `pageCrops[0]` entry from
// /sdcard/ToraScan/.library/index.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

void main(List<String> args) {
  final File source = File(args[0]);
  final String out = args[1];
  CropQuad? crop;
  if (args.length > 2 && args[2] != '-') {
    crop = CropQuad.fromJson(
      jsonDecode(File(args[2]).readAsStringSync()) as Map<String, dynamic>,
    );
  }
  final Uint8List bytes = source.readAsBytesSync();

  // Warm up so the reported time is not dominated by compilation.
  ImagePipeline.processPreset(bytes, ScanPreset.auto, crop: crop);

  final Stopwatch watch = Stopwatch()..start();
  final Uint8List auto = ImagePipeline.processPreset(
    bytes,
    ScanPreset.auto,
    crop: crop,
  );
  watch.stop();

  final File target = File(out);
  target.writeAsBytesSync(auto);
  final img.Image decoded = img.decodeImage(auto)!;

  stdout.writeln(
    '${source.path} -> ${target.path}  ${decoded.width}x${decoded.height}  '
    '${watch.elapsedMilliseconds} ms  ${(auto.length / 1024).round()} KB',
  );
  stdout.writeln('  worst 32px paper block: ${_worstPaperBlock(decoded)}');
}

/// The largest R/G/B spread in the block means of any block that is bright
/// enough to be paper. Colour blotches in a shadow show up here; the ink and
/// any genuinely coloured content sit below the luma cut.
String _worstPaperBlock(img.Image image) {
  const int block = 32;
  double worst = 0;
  int wx = 0;
  int wy = 0;
  img.Pixel worstPixel = image.getPixel(0, 0);
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
      r /= n;
      g /= n;
      b /= n;
      if ((r * 0.299 + g * 0.587 + b * 0.114) < 140) {
        continue;
      }
      final double cast = math.max(
        (r - g).abs(),
        math.max((r - b).abs(), (g - b).abs()),
      );
      if (cast > worst) {
        worst = cast;
        wx = bx;
        wy = by;
        worstPixel = image.getPixel(bx + block ~/ 2, by + block ~/ 2);
      }
    }
  }
  return '${worst.toStringAsFixed(1)} at ($wx,$wy) '
      '${worstPixel.r.toInt()},${worstPixel.g.toInt()},${worstPixel.b.toInt()}';
}
