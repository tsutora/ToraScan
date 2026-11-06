import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a PDF from the scanned page images.
///
/// Pages are placed one per A4 sheet, scaled to fit without cropping or
/// adding any watermark.
class PdfBuilder {
  const PdfBuilder._();

  static Future<void> build({
    required List<String> pagePaths,
    required String outputPath,
  }) async {
    final doc = pw.Document();

    for (final path in pagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }

    await File(outputPath).writeAsBytes(await doc.save(), flush: true);
  }
}
