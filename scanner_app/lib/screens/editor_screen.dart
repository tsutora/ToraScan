import 'dart:io';

import 'package:flutter/material.dart';

import '../models/crop_quad.dart';
import '../models/document_draft.dart';
import '../models/scan_document.dart';
import '../models/scan_preset.dart';
import '../services/document_import.dart';
import '../services/enhance_service.dart';
import '../services/library_paths.dart';
import '../services/pdf_builder.dart';
import '../services/scan_store.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/tora_widgets.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_image.dart';
import '../widgets/page_order_sheet.dart';
import '../widgets/preset_bar.dart';

/// Page browser for one saved document.
///
/// The editor is a dark room on purpose — it is where you judge a page — so it
/// pins the dark token set instead of following the app's brightness.
///
/// Reading is free. Anything that changes the file — a different filter, a new
/// page order, pages merged in from another PDF — happens in an explicit edit
/// mode against an in-memory [DocumentDraft]. The library is only touched when
/// the user taps Save and confirms; leaving the mode throws the draft away.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.document, required this.store});

  final ScanDocument document;
  final ScanStore store;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  /// The editor is always dark, but it borrows the selected family's dark set
  /// so the accent still matches the rest of the app.
  ToraPalette get _p => ToraThemeScope.of(context).family.dark;

  final PageController _controller = PageController();
  int _page = 0;
  bool _busy = false;
  String _busyLabel = 'Working…';

  /// True while the edit mode is open. The viewer stays underneath, reading
  /// from the draft, so the page never jumps when the mode opens.
  bool _editing = false;
  DocumentDraft? _draft;

  /// Renders made while editing, kept beside the document's files until the
  /// edit is saved or discarded.
  Directory? _editDir;
  bool _renderingPage = false;
  int _renderRound = 0;

  ScanDocument get _doc => widget.document;

  int get _pageCount => _editing ? _draft!.length : _doc.pageCount;

  String _pathAt(int index) =>
      _editing ? _draft!.pages[index].displayPath : _doc.pagePaths[index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    await PdfBuilder.build(pagePaths: _doc.pagePaths, outputPath: _doc.pdfPath);
    _doc.touch();
    await widget.store.update(_doc);
  }

  // ------------------------------------------------------------- edit mode

  Future<void> _startEditing() async {
    if (_busy || _editing) {
      return;
    }
    final Directory session = await widget.store.sessionDir(_doc.id);
    final Directory dir = Directory(
      '${session.path}${Platform.pathSeparator}edit_'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = true;
      _draft = DocumentDraft.from(_doc);
      _editDir = dir;
    });
  }

  Future<void> _cancelEditing() async {
    final DocumentDraft? draft = _draft;
    if (!_editing || draft == null) {
      return;
    }

    if (draft.dirty) {
      final bool discard = await confirmDiscard(
        context,
        title: 'Discard changes?',
        message: 'Your edits are not saved. The document stays exactly as it is now.',
        discardLabel: 'Discard changes',
        keepLabel: 'Keep editing',
      );
      if (!discard || !mounted) {
        return;
      }
    }

    final Directory? dir = _editDir;
    setState(() {
      _editing = false;
      _draft = null;
      _editDir = null;
      _page = _page.clamp(0, _doc.pageCount - 1);
    });
    await _discardDir(dir);
  }

  Future<void> _saveEdits() async {
    final DocumentDraft? draft = _draft;
    if (draft == null || !draft.dirty || _busy) {
      return;
    }

    final bool save = await confirmSave(
      context,
      title: 'Save changes?',
      message:
          'This rewrites “${_doc.title}.pdf” and updates the pages in your '
          'library. It cannot be undone.',
    );
    if (!save || !mounted) {
      return;
    }

    try {
      await _run('Saving changes…', () async {
        await _applyDraft(draft);

        final Directory? dir = _editDir;
        if (mounted) {
          setState(() {
            _editing = false;
            _draft = null;
            _editDir = null;
            _page = _page.clamp(0, _doc.pageCount - 1);
          });
        }
        await _discardDir(dir);
      });
    } catch (error) {
      if (mounted) {
        _toast('Could not save the changes: $error');
      }
      return;
    }

    if (!mounted) {
      return;
    }
    _toast('Changes saved.');
  }

  /// Writes the draft over the document's files, then rebuilds the PDF.
  ///
  /// Existing pages are replaced with an atomic rename, so a page is either the
  /// old bytes or the new ones, never a half-written file. Merged pages get the
  /// next free `page_NN.jpg` name and an untouched copy in `orig/`.
  Future<void> _applyDraft(DocumentDraft draft) async {
    final Directory session = await widget.store.sessionDir(_doc.id);
    final String separator = Platform.pathSeparator;
    final Directory pagesDir = Directory(
      '${session.path}$separator${LibraryPaths.pages}',
    );
    final Directory originalsDir = Directory(
      '${session.path}$separator${LibraryPaths.originals}',
    );
    await pagesDir.create(recursive: true);
    await originalsDir.create(recursive: true);

    int next = _nextPageNumber(pagesDir, originalsDir);
    final List<String> pagePaths = <String>[];
    final List<String> originalPaths = <String>[];
    final List<ScanPreset> presets = <ScanPreset>[];
    final List<CropQuad> crops = <CropQuad>[];

    for (final DraftPage page in draft.pages) {
      if (page.isNew) {
        final String name = 'page_${(next++).toString().padLeft(2, '0')}.jpg';
        final String targetPage = '${pagesDir.path}$separator$name';
        final String targetOriginal = '${originalsDir.path}$separator$name';
        await File(page.displayPath).copy(targetPage);
        await File(page.tempOriginalPath ?? page.pagePath).copy(targetOriginal);
        pagePaths.add(targetPage);
        originalPaths.add(targetOriginal);
      } else {
        final String? render = page.renderPath;
        if (render != null && render != page.pagePath) {
          // Copy to a sibling staging file, then replace the page in one
          // rename. A page is never left half-written, and the render stays
          // available if a later page fails and the save is retried.
          final String staging = '${page.pagePath}.new';
          try {
            await File(render).copy(staging);
            try {
              await File(staging).rename(page.pagePath);
            } on FileSystemException {
              await File(staging).copy(page.pagePath);
            }
          } finally {
            try {
              final File leftover = File(staging);
              if (await leftover.exists()) {
                await leftover.delete();
              }
            } catch (_) {
              // The rename already consumed it.
            }
          }
          await evictPage(page.pagePath);
        }
        pagePaths.add(page.pagePath);
        originalPaths.add(page.originalPath);
      }
      presets.add(page.preset);
      crops.add(page.crop);
    }

    _doc.pagePaths
      ..clear()
      ..addAll(pagePaths);
    _doc.originalPaths
      ..clear()
      ..addAll(originalPaths);
    _doc.pagePresets
      ..clear()
      ..addAll(presets);
    _doc.pageCrops
      ..clear()
      ..addAll(crops);
    await _save();
  }

  /// The first `page_NN` number that is not in use by a page or an original.
  static int _nextPageNumber(Directory pages, Directory originals) {
    final RegExp pattern = RegExp(r'^page_(\d+)\.');
    int max = 0;
    for (final Directory dir in <Directory>[pages, originals]) {
      if (!dir.existsSync()) {
        continue;
      }
      for (final FileSystemEntity entity in dir.listSync()) {
        final String name = entity.path.split(Platform.pathSeparator).last;
        final RegExpMatch? match = pattern.firstMatch(name);
        final int number = int.tryParse(match?.group(1) ?? '') ?? 0;
        if (number > max) {
          max = number;
        }
      }
    }
    return max + 1;
  }

  /// Deletes an edit's scratch folder once nothing points at it any more.
  static Future<void> _discardDir(Directory? dir) async {
    if (dir == null) {
      return;
    }
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // A cache folder that cannot be removed is harmless; the next edit
      // starts a fresh one.
    }
  }

  /// Applies the current page's filter to every page.
  Future<void> _applyPresetToAll() async {
    final DocumentDraft? draft = _draft;
    if (draft == null || _busy || _renderingPage) {
      return;
    }
    final ScanPreset preset = draft.pages[_page].preset;

    setState(() {
      _busy = true;
      _busyLabel = 'Rendering pages…';
    });
    bool changed = false;
    try {
      for (int i = 0; i < draft.pages.length; i++) {
        final DraftPage page = draft.pages[i];
        if (page.preset == preset) {
          continue;
        }
        changed = true;
        if (mounted) {
          setState(
            () => _busyLabel =
                'Rendering page ${i + 1} of '
                '${draft.pages.length}…',
          );
        }

        if (preset == page.sourcePreset) {
          final String? old = page.renderPath;
          page.preset = preset;
          page.renderPath = null;
          await _deleteQuietly(old);
          continue;
        }

        final String out = _renderPath(i);
        await EnhanceService.apply(
          sourcePath: page.originalPath,
          outputPath: out,
          preset: preset,
          crop: page.crop,
          maxEdge: _doc.quality.maxEdge,
          quality: _doc.quality.jpegQuality,
        );
        await evictPage(out);
        final String? old = page.renderPath;
        page.preset = preset;
        page.renderPath = out;
        await _deleteQuietly(old);
      }
      if (changed) {
        draft.markDirty();
      }
    } catch (_) {
      if (mounted) {
        _toast('Could not apply that filter to every page.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // ---------------------------------------------------------------- filters

  Future<void> _choosePreset(ScanPreset preset) async {
    final DocumentDraft? draft = _draft;
    if (draft == null || _renderingPage || _busy) {
      return;
    }

    final int index = _page;
    final DraftPage page = draft.pages[index];
    if (page.preset == preset) {
      return;
    }

    // Back to what the page already has on disk: drop the render instead of
    // keeping a duplicate.
    if (preset == page.sourcePreset) {
      final String? old = page.renderPath;
      setState(() => draft.setRender(index, preset: preset, renderPath: null));
      await _deleteQuietly(old);
      return;
    }

    setState(() => _renderingPage = true);
    try {
      final String out = _renderPath(index);
      await EnhanceService.apply(
        sourcePath: page.originalPath,
        outputPath: out,
        preset: preset,
        crop: page.crop,
        maxEdge: _doc.quality.maxEdge,
        quality: _doc.quality.jpegQuality,
      );
      await evictPage(out);
      if (!mounted) {
        return;
      }
      final String? old = page.renderPath;
      setState(() => draft.setRender(index, preset: preset, renderPath: out));
      await _deleteQuietly(old);
    } catch (_) {
      if (mounted) {
        _toast('Could not apply that filter.');
      }
    } finally {
      if (mounted) {
        setState(() => _renderingPage = false);
      }
    }
  }

  String _renderPath(int index) =>
      '${_editDir!.path}${Platform.pathSeparator}'
      'render_${++_renderRound}_${index + 1}.jpg';

  // ---------------------------------------------------------------- reorder

  Future<void> _openReorder() async {
    final DocumentDraft? draft = _draft;
    if (draft == null || _busy) {
      return;
    }

    final int before = _page;
    final List<int>? order = await PageOrderSheet.show(
      context,
      thumbnails: <ImageProvider>[
        for (int i = 0; i < draft.length; i++)
          pageImage(draft.pages[i].displayPath, cacheWidth: 102),
      ],
      palette: _p,
    );
    if (order == null || !mounted) {
      return;
    }
    if (!_moved(order)) {
      return;
    }

    setState(() {
      draft.applyOrder(order);
      _page = order.indexOf(before);
    });
    if (_controller.hasClients) {
      _controller.jumpToPage(_page);
    }
  }

  /// Scrolls to [index] once the page view knows how many pages it has.
  ///
  /// After a merge the page count grows in the same frame the jump is wanted.
  /// A jump made before the view has laid the new pages out is clamped to the
  /// old last page, so the viewer silently stays where it was. Retrying for a
  /// few frames until the controller really reports [index] makes the new
  /// pages visible, and keeps the header honest.
  void _jumpWhenReady(int index, [int tries = 4]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      _controller.jumpToPage(index);
      final double? at = _controller.page;
      if (tries > 1 && (at == null || (at - index).abs() > 0.01)) {
        _jumpWhenReady(index, tries - 1);
      }
    });
  }

  // ------------------------------------------------------------------ merge

  Future<void> _mergePdf() async {
    final DocumentDraft? draft = _draft;
    if (draft == null || _busy || _renderingPage) {
      return;
    }

    final String? pdf = await DocumentImport.pickPdf();
    if (pdf == null || !mounted) {
      return;
    }

    final Directory dir = Directory(
      '${_editDir!.path}${Platform.pathSeparator}merge_'
      '${DateTime.now().microsecondsSinceEpoch}',
    );

    setState(() {
      _busy = true;
      _busyLabel = 'Reading PDF…';
    });
    try {
      final List<String> pages = await DocumentImport.rasterizePdf(
        pdf,
        dir,
        onPage: (int page) {
          if (mounted) {
            setState(() => _busyLabel = 'Importing page $page…');
          }
        },
      );
      if (pages.isEmpty) {
        if (mounted) {
          _toast('That PDF has no pages.');
        }
        return;
      }

      final int first = draft.length;
      draft.addAll(<DraftPage>[
        for (final String path in pages)
          DraftPage(
            pagePath: path,
            originalPath: path,
            preset: ScanPreset.none,
            sourcePreset: ScanPreset.none,
            crop: CropQuad.full(),
            isNew: true,
            tempOriginalPath: path,
          ),
      ]);

      if (!mounted) {
        return;
      }
      setState(() => _page = first);
      _jumpWhenReady(first);
    } catch (error) {
      if (mounted) {
        _toast('Could not merge that PDF: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // ------------------------------------------------------- read-only actions

  Future<void> _deletePage() async {
    if (_doc.pageCount <= 1) {
      _toast('A document needs at least one page.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete page ${_page + 1}?'),
        content: const Text(
          'The page is removed from this document and its PDF.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _run('Removing page…', () async {
      final String pagePath = _doc.pagePaths[_page];
      final String originalPath = _doc.originalPaths[_page];
      _doc.removePage(_page);
      await _deleteQuietly(pagePath);
      await _deleteQuietly(originalPath);
      _page = _page.clamp(0, _doc.pageCount - 1);
      await _save();
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sharePdf() => ShareService.sharePdf(_doc);

  Future<void> _shareJpg() => ShareService.shareJpg(_doc);

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) {
      return;
    }
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _moved(List<int> order) {
    for (int i = 0; i < order.length; i++) {
      if (order[i] != i) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Theme(
      data: AppTheme.dark(_p),
      child: Builder(
        builder: (BuildContext context) => PopScope(
          // In edit mode back closes the mode, not the document. A system back
          // therefore goes through the same discard check as the close button.
          canPop: !_editing,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && _editing) {
              _cancelEditing();
            }
          },
          child: Scaffold(
            backgroundColor: _p.bg,
            appBar: _appBar(text),
            body: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    if (_renderingPage)
                      LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: _p.line,
                        color: _p.accent,
                      ),
                    Expanded(child: _viewer()),
                    if (_editing) _editBar(),
                  ],
                ),
                if (_busy) _busyOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _appBar(TextTheme text) {
    if (_editing) {
      final bool dirty = _draft?.dirty ?? false;
      return AppBar(
        backgroundColor: _p.bg,
        foregroundColor: _p.ink,
        leading: IconButton(
          tooltip: 'Cancel editing',
          onPressed: _busy ? null : _cancelEditing,
          icon: const Icon(Icons.close, size: 22),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ToraLabel('Edit file', color: _p.ink),
            ToraMicro('Page ${_page + 1} of $_pageCount', color: _p.inkFaint),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save changes',
            onPressed: (dirty && !_busy) ? _saveEdits : null,
            icon: const Icon(Icons.check, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      );
    }

    return AppBar(
      backgroundColor: _p.bg,
      foregroundColor: _p.ink,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _doc.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(color: _p.ink),
          ),
          ToraMicro(
            'Page ${_page + 1} of ${_doc.pageCount}',
            color: _p.inkFaint,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: _busy ? null : _startEditing,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('EDIT'),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: _p.ink),
          onSelected: (String value) {
            switch (value) {
              case 'share':
                _sharePdf();
              case 'shareJpg':
                _shareJpg();
              case 'delete':
                _deletePage();
            }
          },
          itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'share', child: Text('Share PDF')),
            PopupMenuItem<String>(
              value: 'shareJpg',
              child: Text('Share as JPG'),
            ),
            PopupMenuItem<String>(value: 'delete', child: Text('Delete page')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _viewer() {
    return PageView.builder(
      controller: _controller,
      itemCount: _pageCount,
      onPageChanged: (int index) => setState(() => _page = index),
      itemBuilder: (BuildContext context, int index) {
        final String path = _pathAt(index);
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image(
              image: pageImage(path),
              key: ValueKey<String>(
                '$path-${_doc.updatedAt.microsecondsSinceEpoch}',
              ),
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }

  Widget _editBar() {
    final DocumentDraft? draft = _draft;
    if (draft == null) {
      return const SizedBox.shrink();
    }
    final ScanPreset current = draft.pages[_page].preset;

    return SafeArea(
      top: false,
      child: Container(
        color: _p.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: <Widget>[
                  ToraMicro('Filter · page ${_page + 1}', color: _p.inkFaint),
                  const Spacer(),
                  TextButton(
                    onPressed: (_busy || _renderingPage)
                        ? null
                        : _applyPresetToAll,
                    child: const Text('APPLY TO ALL'),
                  ),
                ],
              ),
            ),
            PresetBar(
              selected: current,
              enabled: !_busy && !_renderingPage,
              onSelected: _choosePreset,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: (_busy || _renderingPage) ? null : _openReorder,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: const Text('REORDER PAGES'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: (_busy || _renderingPage) ? null : _mergePdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('MERGE PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _busyOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC0F1113),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 14),
              ToraLabel(_busyLabel, color: _p.ink),
            ],
          ),
        ),
      ),
    );
  }
}
