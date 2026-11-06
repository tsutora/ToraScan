import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_document.dart';
import 'library_paths.dart';

/// Hands a scan to the Android share sheet, as a PDF or as JPG pages.
class ShareService {
  const ShareService._();

  static Future<void> sharePdf(ScanDocument doc) async {
    final File file = File(doc.pdfPath);
    if (!await file.exists()) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(doc.pdfPath, mimeType: 'application/pdf')],
        text: doc.title,
      ),
    );
  }

  /// Shares every page as a JPG, in page order.
  ///
  /// The files are copied to a cache directory first so the share sheet shows
  /// the document's own name instead of an internal `.library` path, and so
  /// other apps cannot get a handle on the working copies.
  static Future<void> shareJpg(ScanDocument doc) async {
    final List<XFile> files = await jpgFiles(doc);
    if (files.isEmpty) {
      return;
    }
    await SharePlus.instance.share(ShareParams(files: files, text: doc.title));
  }

  static Future<List<XFile>> jpgFiles(ScanDocument doc) async {
    final Directory cache = await getTemporaryDirectory();
    final String root = '${cache.path}${Platform.pathSeparator}share';
    final Directory dir = Directory('$root${Platform.pathSeparator}${doc.id}');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    final String stem = LibraryPaths.safeName(doc.title);
    final List<XFile> files = <XFile>[];
    for (int i = 0; i < doc.pagePaths.length; i++) {
      final File source = File(doc.pagePaths[i]);
      if (!await source.exists()) {
        continue;
      }
      final String name = doc.pagePaths.length == 1
          ? '$stem.jpg'
          : '$stem ${(i + 1).toString().padLeft(2, '0')}.jpg';
      final String target = '${dir.path}${Platform.pathSeparator}$name';
      await source.copy(target);
      files.add(XFile(target, mimeType: 'image/jpeg'));
    }
    return files;
  }
}
