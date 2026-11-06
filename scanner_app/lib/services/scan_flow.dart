import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/crop_quad.dart';
import '../models/scan_capture.dart';
import '../models/scan_document.dart';
import '../models/scan_mode.dart';
import '../models/save_quality.dart';
import '../models/scan_preset.dart';
import '../screens/crop_screen.dart';
import '../screens/preview_screen.dart';
import '../screens/scanner_screen.dart';
import '../services/document_import.dart';
import '../services/pdf_builder.dart';
import '../services/scan_processor.dart';
import '../services/scan_store.dart';
import '../theme/app_theme.dart';
import '../theme/tora_widgets.dart';
import '../widgets/name_dialog.dart';
import '../widgets/share_sheet.dart';

/// What the mode sheet chose: a camera session, or a PDF to import.
sealed class ScanStart {
  const ScanStart();
}

class CameraScanStart extends ScanStart {
  const CameraScanStart(this.mode);

  final ScanMode mode;
}

class PdfScanStart extends ScanStart {
  const PdfScanStart();
}

/// The capture-to-library pipeline: pick a mode, scan, adjust the crops, name
/// it, render the pages, build the PDF, then offer to share it.
///
/// Kept in one place so the home screen and the folder screens cannot drift
/// apart in how a scan is created.
class ScanFlow {
  const ScanFlow._();

  static Future<ScanDocument?> run(
    BuildContext context, {
    required ScanStore store,
    String? folderId,
    ScanPreset preset = ScanPreset.auto,
  }) async {
    final ScanStart? start = await pickMode(context);
    if (start == null || !context.mounted) {
      return null;
    }

    ScanPreset initialPreset = preset;
    final List<ScanCapture>? shots;
    if (start is CameraScanStart) {
      shots = await Navigator.of(context).push<List<ScanCapture>>(
        MaterialPageRoute<List<ScanCapture>>(
          builder: (_) => ScannerScreen(mode: start.mode),
        ),
      );
    } else {
      // A PDF page is already a page. The scanner's auto-crop and auto
      // enhancement would second-guess it, so imported pages start unfiltered
      // and uncropped; the preview still offers both.
      initialPreset = ScanPreset.none;
      shots = await _importPdf(context);
    }

    if (shots == null || shots.isEmpty || !context.mounted) {
      if (shots != null) {
        await _discard(shots);
      }
      return null;
    }

    final List<String> captured = shots
        .map((ScanCapture shot) => shot.rawPath)
        .toList();
    final List<CropQuad> detected = shots
        .map((ScanCapture shot) => shot.quad)
        .toList();

    // The auto-crop is already applied, but the edges are still adjustable.
    final List<CropQuad>? quads = await Navigator.of(context)
        .push<List<CropQuad>>(
          MaterialPageRoute<List<CropQuad>>(
            builder: (_) => CropScreen(pages: captured, initialQuads: detected),
          ),
        );
    if (quads == null || !context.mounted) {
      await _discard(shots);
      return null;
    }

    // Last look before anything is written to the library. The filter is
    // chosen here, and the pages come back already rendered, so confirming is
    // the only step that commits.
    final PreviewResult? preview = await Navigator.of(context)
        .push<PreviewResult>(
          MaterialPageRoute<PreviewResult>(
            builder: (_) => PreviewScreen(
              captures: captured,
              quads: quads,
              workDir: Directory(
                '${File(captured.first).parent.path}${Platform.pathSeparator}'
                'preview',
              ),
              initialPreset: initialPreset,
            ),
          ),
        );
    if (preview == null || !context.mounted) {
      await _discard(shots);
      return null;
    }

    final DateTime now = DateTime.now();
    final String suggestion =
        'Scan ${DateFormat('d MMM yyyy HH.mm').format(now)}';
    final String? name = await showNameDialog(context, initial: suggestion);
    if (name == null || !context.mounted) {
      await _discard(shots);
      return null;
    }

    late final ScanDocument doc;
    try {
      doc = await _withProgress<ScanDocument>(
        context,
        (void Function(String) report) => _render(
          store: store,
          // The preview may have reordered the pages or re-cropped one, so it
          // owns the final pairing of capture to crop.
          captured: preview.captures,
          renderedPages: preview.pagePaths,
          quads: preview.quads,
          name: name,
          presets: preview.presets,
          quality: preview.quality,
          folderId: folderId,
          now: now,
          report: report,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the scan: $error')),
        );
      }
      return null;
    }

    if (!context.mounted) {
      return null;
    }

    // The file is on disk; offer to send it straight away.
    final bool open = await ShareSheet.show(context, doc);
    return open ? doc : null;
  }

  /// Asks for a camera session or a PDF before anything opens.
  static Future<ScanStart?> pickMode(BuildContext context) {
    return showModalBottomSheet<ScanStart>(
      context: context,
      builder: (BuildContext context) => const _ModeSheet(),
    );
  }

  /// Picks a PDF, rasterises it, and turns every page into a capture.
  ///
  /// The rasterised pages and the normalised captures live in one temporary
  /// session folder, so the same [_discard] that cleans up a cancelled camera
  /// session also cleans this up.
  static Future<List<ScanCapture>?> _importPdf(BuildContext context) async {
    final String? pdf = await DocumentImport.pickPdf();
    if (pdf == null || !context.mounted) {
      return null;
    }

    try {
      return await _withProgress<List<ScanCapture>>(context, (
        void Function(String) report,
      ) async {
        final Directory cache = await getTemporaryDirectory();
        final String separator = Platform.pathSeparator;
        final Directory dir = Directory(
          '${cache.path}${separator}import$separator'
          '${DateTime.now().microsecondsSinceEpoch}',
        );

        final List<String> raster = await DocumentImport.rasterizePdf(
          pdf,
          Directory('${dir.path}${separator}pdf'),
          onPage: (int page) => report('Importing page $page…'),
        );

        final List<ScanCapture> captures = <ScanCapture>[];
        for (int i = 0; i < raster.length; i++) {
          final String stamp = (i + 1).toString().padLeft(2, '0');
          report('Preparing page ${i + 1} of ${raster.length}…');
          captures.add(
            await ScanProcessor.prepare(
              sourcePath: raster[i],
              rawPath: '${dir.path}${separator}raw_$stamp.jpg',
              thumbPath: '${dir.path}${separator}thumb_$stamp.jpg',
              detectCrop: false,
            ),
          );
        }
        return captures;
      }, initialLabel: 'Reading PDF…');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import that PDF: $error')),
        );
      }
      return null;
    }
  }

  /// Deletes the camera's working copies when a session is abandoned — the
  /// user backed out of the crop, the name dialog or the save. The pages were
  /// never filed, so nothing of value is lost and the cache does not fill up
  /// with full-size frames.
  static Future<void> _discard(List<ScanCapture> shots) async {
    if (shots.isEmpty) {
      return;
    }

    // Every shot of a session shares one folder, and nothing in it is needed
    // any more.
    try {
      final Directory session = File(shots.first.rawPath).parent;
      if (await session.exists()) {
        await session.delete(recursive: true);
        return;
      }
    } catch (_) {
      // Fall through to deleting the files one by one.
    }

    for (final ScanCapture shot in shots) {
      for (final String path in <String>[shot.rawPath, shot.thumbPath]) {
        if (path.isEmpty) {
          continue;
        }
        try {
          await File(path).delete();
        } catch (_) {
          // Already gone, or the system cleaned it up.
        }
      }
    }
  }

  static Future<ScanDocument> _render({
    required ScanStore store,
    required List<String> captured,
    required List<String> renderedPages,
    required List<CropQuad> quads,
    required String name,
    required List<ScanPreset> presets,
    required SaveQuality quality,
    required String? folderId,
    required DateTime now,
    required void Function(String) report,
  }) async {
    report('Preparing pages…');

    final String id = now.microsecondsSinceEpoch.toString();
    final Directory dir = await store.sessionDir(id);
    final String separator = Platform.pathSeparator;
    final Directory originals = Directory('${dir.path}${separator}orig');
    final Directory working = Directory('${dir.path}${separator}pages');
    await originals.create(recursive: true);
    await working.create(recursive: true);

    final List<String> originalPaths = <String>[];
    final List<String> pagePaths = <String>[];

    for (int i = 0; i < captured.length; i++) {
      final String extension = captured[i].split('.').last;
      final String fileName =
          'page_${(i + 1).toString().padLeft(2, '0')}.$extension';
      final String original = '${originals.path}$separator$fileName';
      final String page = '${working.path}$separator$fileName';

      await File(captured[i]).copy(original);
      originalPaths.add(original);
      pagePaths.add(page);
    }

    // The pages were rendered by the preview at the quality the library keeps,
    // so they are adopted rather than rebuilt — the user already approved these
    // exact bytes. Re-rendering here would double the wait for no gain, and
    // would risk the saved page differing from the one that was confirmed.
    for (int i = 0; i < renderedPages.length; i++) {
      report('Saving page ${i + 1} of ${renderedPages.length}…');
      await File(renderedPages[i]).copy(pagePaths[i]);
    }

    // The camera's working copy is no longer needed once the originals are in
    // the library; the thumbnails and the preview renders live in the same
    // folder, so the whole session directory goes.
    try {
      final Directory session = File(captured.first).parent;
      if (await session.exists()) {
        await session.delete(recursive: true);
      }
    } catch (_) {
      // A cache folder that cannot be removed is harmless.
    }

    report('Building PDF…');
    final String pdfPath = await store.pdfPathFor(
      folderId: folderId,
      title: name,
    );
    await PdfBuilder.build(pagePaths: pagePaths, outputPath: pdfPath);

    final ScanDocument doc = ScanDocument(
      id: id,
      title: name,
      pagePaths: pagePaths,
      originalPaths: originalPaths,
      pagePresets: List<ScanPreset>.from(presets),
      pageCrops: List<CropQuad>.from(quads),
      pdfPath: pdfPath,
      createdAt: now,
      folderId: folderId,
      quality: quality,
    );
    await store.add(doc);
    return doc;
  }

  static Future<T> _withProgress<T>(
    BuildContext context,
    Future<T> Function(void Function(String) report) action, {
    String initialLabel = 'Saving…',
  }) async {
    final ValueNotifier<String> label = ValueNotifier<String>(initialLabel);
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => _ProgressDialog(label: label),
      ),
    );

    try {
      return await action((String value) => label.value = value);
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => label.dispose());
    }
  }
}

/// Single page, a batch session, or a PDF. Three rows, no ceremony.
class _ModeSheet extends StatelessWidget {
  const _ModeSheet();

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ToraLabel('Scan'),
            const SizedBox(height: 14),
            ToraRule(),
            _ModeRow(
              icon: Icons.crop_portrait,
              title: 'Single page',
              onTap: () => Navigator.pop(
                context,
                const CameraScanStart(ScanMode.single),
              ),
            ),
            _ModeRow(
              icon: Icons.filter_none,
              title: 'Batch',
              onTap: () =>
                  Navigator.pop(context, const CameraScanStart(ScanMode.batch)),
            ),
            _ModeRow(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Import PDF',
              onTap: () => Navigator.pop(context, const PdfScanStart()),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: toraType(
                    10,
                    FontWeight.w700,
                    tracking: 1.2,
                    color: p.inkFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: p.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.label});

  final ValueNotifier<String> label;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 18),
              Flexible(
                child: ValueListenableBuilder<String>(
                  valueListenable: label,
                  builder:
                      (BuildContext context, String value, Widget? child) =>
                          Text(
                            value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
