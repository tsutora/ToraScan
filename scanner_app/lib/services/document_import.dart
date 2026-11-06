import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

/// Imports documents the user already has: images from the gallery and pages
/// from a PDF.
///
/// A PDF is rasterised once, page by page, into JPEG files. From there the
/// pages are ordinary captures — they can be cropped, filtered, reordered and
/// merged into a saved document exactly like a camera shot. That keeps one
/// pipeline for every page instead of a second, PDF-shaped one.
class DocumentImport {
  const DocumentImport._();

  /// Long side the platform PDF renderer aims for. 200 dpi on A4 is 2339 px,
  /// just under the size the image pipeline keeps, so a text page stays crisp
  /// without producing a 12 MP intermediate.
  static const double pdfDpi = 200;

  /// Asks for a PDF and returns its path, or null when the user backs out.
  ///
  /// The Android plugin copies the chosen file into the app's cache and hands
  /// back a real path, so the PDF is readable without any storage permission
  /// and stays readable after the picker closes.
  static Future<String?> pickPdf() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
    );
    final String? path = file?.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }

  /// Renders every page of [pdfPath] into [outDir] as a JPEG, in page order.
  ///
  /// [onPage] is called with the 1-based page number as each one lands, which
  /// is the only progress information available while the stream is running.
  static Future<List<String>> rasterizePdf(
    String pdfPath,
    Directory outDir, {
    void Function(int page)? onPage,
  }) async {
    final Uint8List bytes = await File(pdfPath).readAsBytes();
    await outDir.create(recursive: true);

    final List<String> pages = <String>[];
    await for (final PdfRaster raster in Printing.raster(bytes, dpi: pdfDpi)) {
      final int number = pages.length + 1;
      final String path =
          '${outDir.path}${Platform.pathSeparator}'
          'page_${number.toString().padLeft(3, '0')}.jpg';
      await compute(_encodeRaster, <Object?>[
        path,
        raster.width,
        raster.height,
        raster.pixels,
      ]);
      pages.add(path);
      onPage?.call(number);
    }
    return pages;
  }
}

/// Encodes one RGBA page from the platform renderer as a JPEG.
///
/// The renderer leaves areas the PDF does not paint transparent, and JPEG has
/// no alpha channel. Dropping the alpha would turn a page's white margins
/// black, so the page is composited onto white paper first.
Future<void> _encodeRaster(List<Object?> args) async {
  final String path = args[0]! as String;
  final int width = args[1]! as int;
  final int height = args[2]! as int;
  final Uint8List pixels = args[3]! as Uint8List;

  final img.Image rgba = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    format: img.Format.uint8,
    numChannels: 4,
  );

  final img.Image paper = img.Image(
    width: width,
    height: height,
    format: img.Format.uint8,
    numChannels: 3,
  );
  img.fill(paper, color: img.ColorRgb8(255, 255, 255));

  final img.Image page = img.compositeImage(paper, rgba);
  await File(path).writeAsBytes(img.encodeJpg(page, quality: 92), flush: true);
}
