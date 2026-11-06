// Renders the enhancement presets on a synthetic "photo of a page" so the
// result can be inspected without a device.
//
//   dart run tool/preview.dart
//
// Output: preview/<preset>.png
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/image_pipeline.dart';

/// A page photographed badly: warm cast, soft shadow falling across it,
/// slightly low contrast, plus text-like marks.
Uint8List syntheticPhoto({int width = 900, int height = 1240}) {
  final img.Image image = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Diagonal shadow gradient: bright at top-left, dim at bottom-right.
      final double shade = 1.0 - 0.38 * ((x / width) * 0.6 + (y / height) * 0.4);
      final int base = (232 * shade).round().clamp(0, 255);
      image.setPixelRgb(
        x,
        y,
        (base * 1.02).round().clamp(0, 255),
        (base * 0.985).round().clamp(0, 255),
        (base * 0.9).round().clamp(0, 255),
      );
    }
  }

  // Title block.
  img.fillRect(
    image,
    x1: 90,
    y1: 90,
    x2: 520,
    y2: 118,
    color: img.ColorRgb8(38, 38, 44),
  );

  // Body text as bars of varying length.
  for (int line = 0; line < 18; line++) {
    final int top = 170 + line * 34;
    final int right = line % 5 == 4 ? 640 : 810;
    img.fillRect(
      image,
      x1: 90,
      y1: top,
      x2: right,
      y2: top + 13,
      color: img.ColorRgb8(52, 52, 58),
    );
  }

  // A small table so edges and thin lines are visible.
  for (int row = 0; row < 5; row++) {
    img.drawRect(
      image,
      x1: 90,
      y1: 800 + row * 56,
      x2: 810,
      y2: 800 + row * 56 + 56,
      color: img.ColorRgb8(70, 70, 76),
      thickness: 2,
    );
  }

  return img.encodeJpg(image, quality: 92);
}

void main() {
  final Directory out = Directory('preview');
  out.createSync(recursive: true);

  final Uint8List source = syntheticPhoto();
  File('${out.path}/00-source.jpg').writeAsBytesSync(source);

  for (final ScanPreset preset in ScanPreset.values) {
    final Uint8List result = ImagePipeline.processPreset(source, preset);
    final String name = preset.name.padLeft(2, '0');
    final File file = File('${out.path}/$name-${preset.name}.png');
    final img.Image? decoded = img.decodeImage(result);
    file.writeAsBytesSync(decoded == null ? result : img.encodePng(decoded));
    stdout.writeln('${file.path}  (${(result.length / 1024).round()} KB jpeg)');
  }
}
