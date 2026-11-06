import 'dart:io';

import 'package:flutter/material.dart';

import '../models/crop_quad.dart';
import '../models/save_quality.dart';
import '../models/scan_preset.dart';
import '../services/enhance_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/tora_widgets.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_image.dart';
import '../widgets/page_order_sheet.dart';
import '../widgets/preset_bar.dart';
import 'crop_screen.dart';

/// What the preview hands back to the scan flow.
///
/// The pages are already rendered at full quality, so saving them is a file
/// copy rather than a second enhancement pass. The captures and crops come back
/// too, in the order the user finally chose: the flow stores the originals and
/// the crop for each page beside the render, so a later crop must be paired with
/// the same capture it was drawn on.
class PreviewResult {
  const PreviewResult({
    required this.presets,
    required this.quality,
    required this.pagePaths,
    required this.captures,
    required this.quads,
  });

  final List<ScanPreset> presets;
  final SaveQuality quality;
  final List<String> pagePaths;
  final List<String> captures;
  final List<CropQuad> quads;
}

/// The last look before the PDF is written.
///
/// Every page arrives cropped and filtered, and the filter is chosen *here*
/// rather than after the fact: the decision belongs to the moment of saving,
/// while the whole document is on screen and still free to change. Whatever is
/// confirmed here is what lands in the library, byte for byte.
///
/// The two things still worth changing at this point are the two that reshape
/// the document — the edges of the page you are looking at, and the order of the
/// pages — so both are one tap away rather than a trip back through the flow.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.captures,
    required this.quads,
    required this.workDir,
    this.initialPreset = ScanPreset.auto,
  });

  /// The untouched captures, in page order.
  final List<String> captures;

  /// The crop chosen for each capture.
  final List<CropQuad> quads;

  /// Scratch directory for the rendered pages. It lives inside the capture
  /// session, so cancelling deletes it along with everything else.
  final Directory workDir;

  final ScanPreset initialPreset;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  /// The preview is a dark room too — it is where the page is judged.
  ToraPalette get _p => ToraThemeScope.of(context).family.dark;

  final PageController _controller = PageController();

  /// The filter is per page: a form can be colour on one page and grey on the
  /// next. The bar edits the page on screen, and APPLY ALL copies it across.
  late List<ScanPreset> _presets;

  /// Compression for the files this scan will keep.
  SaveQuality _quality = SaveQuality.original;

  /// All four lists are parallel and permuted together when the pages are
  /// reordered: the capture a page was made from, the crop drawn on it, and the
  /// rendered file that is shown and eventually saved.
  late List<String> _captures;
  late List<CropQuad> _quads;
  late List<String> _pages;

  int _page = 0;
  int _round = 0;
  bool _rendering = false;

  /// True while a single page is being re-rendered after a crop change, so the
  /// progress line can say which page rather than count a whole batch.
  bool _partial = false;

  @override
  void initState() {
    super.initState();
    _captures = List<String>.from(widget.captures);
    _quads = List<CropQuad>.from(widget.quads);
    _presets = List<ScanPreset>.filled(
      _captures.length,
      widget.initialPreset,
    );
    _pages = List<String>.filled(_captures.length, '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A fresh name every round. Re-using one path would hand the image cache the
  /// same key for different bytes, and the page would keep showing the previous
  /// filter — which is exactly the bug this screen has to not repeat.
  String _pathFor(int round, int index) =>
      '${widget.workDir.path}${Platform.pathSeparator}'
      'preview_${round}_${index + 1}.jpg';

  /// Renders the pages at the quality the library keeps.
  ///
  /// With [only] set, just that page is rebuilt — a crop change on one page
  /// should not cost a whole batch — and the rest keep their existing files.
  Future<void> _render({int? only}) async {
    if (_rendering) {
      return;
    }

    setState(() {
      _rendering = true;
      _partial = only != null;
    });

    final int round = ++_round;
    final List<String> stale = List<String>.from(_pages);

    try {
      await widget.workDir.create(recursive: true);

      // The page the user is looking at is rendered first, so the filter feels
      // immediate even when the batch is long.
      final List<int> order = only != null
          ? <int>[only]
          : <int>[
              for (int i = _page; i < _pages.length; i++) i,
              for (int i = 0; i < _page; i++) i,
            ];

      for (final int index in order) {
        if (!mounted) {
          return;
        }
        final String out = _pathFor(round, index);
        await EnhanceService.apply(
          sourcePath: _captures[index],
          outputPath: out,
          preset: _presets[index],
          crop: _quads[index],
          maxEdge: _quality.maxEdge,
          quality: _quality.jpegQuality,
        );
        await evictPage(out);
        if (!mounted) {
          return;
        }
        setState(() => _pages[index] = out);
      }

      // Drop the previous round's files. The session directory would take them
      // with it on cancel, but a long filter session should not grow unbounded.
      // A page that was re-rendered on its own keeps the other pages' paths in
      // [_pages], so only genuinely replaced files are deleted.
      for (final String path in stale) {
        if (path.isEmpty || _pages.contains(path)) {
          continue;
        }
        try {
          await File(path).delete();
        } catch (_) {
          // Already gone.
        }
      }
    } catch (_) {
      // Backing out of this screen deletes the work directory underneath a
      // render that is still running, and that is not worth reporting. A real
      // failure is: without this the save button would spin forever.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not render this page.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _rendering = false);
      }
    }
  }

  void _choosePreset(ScanPreset preset) {
    if (preset == _presets[_page] || _rendering) {
      return;
    }
    setState(() => _presets[_page] = preset);
    _render(only: _page);
  }

  /// Copies the filter on screen to every page, then re-renders the set.
  void _applyPresetToAll() {
    if (_rendering || _pages.length < 2) {
      return;
    }
    final ScanPreset preset = _presets[_page];
    bool changed = false;
    for (int i = 0; i < _presets.length; i++) {
      if (_presets[i] != preset) {
        _presets[i] = preset;
        changed = true;
      }
    }
    if (!changed) {
      return;
    }
    setState(() {});
    _render();
  }

  /// Opens the compression chooser. Changing it re-renders every page,
  /// because the page files themselves are what the PDF embeds.
  Future<void> _chooseQuality() async {
    if (_rendering) {
      return;
    }
    final SaveQuality? chosen = await showModalBottomSheet<SaveQuality>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _p.surface,
      builder: (BuildContext context) => _QualitySheet(selected: _quality),
    );
    if (chosen == null || chosen == _quality || !mounted) {
      return;
    }
    setState(() => _quality = chosen);
    await _render();
  }

  /// Reopens the eight-point crop for the page on screen.
  ///
  /// It starts from the untouched capture, so the edges can be pulled back out
  /// after an earlier crop, and the result replaces this page's quad — the other
  /// pages are left exactly as they are.
  Future<void> _editCrop() async {
    if (_rendering || _pages.isEmpty) {
      return;
    }

    final int index = _page;
    final List<CropQuad>? result = await Navigator.of(context)
        .push<List<CropQuad>>(
          MaterialPageRoute<List<CropQuad>>(
            builder: (_) => CropScreen(
              pages: <String>[_captures[index]],
              initialQuads: <CropQuad>[_quads[index]],
              title: 'Crop page ${index + 1} of ${_pages.length}',
              doneLabel: 'Apply crop',
            ),
          ),
        );

    if (result == null || result.isEmpty || !mounted) {
      return;
    }
    if (_sameCrop(result.first, _quads[index])) {
      return;
    }

    _quads[index] = result.first;
    await _render(only: index);
  }

  /// Lets the user drag the pages into a different order. Nothing is rendered
  /// again: the same files simply change places, and the page being viewed
  /// follows to its new position.
  Future<void> _openReorder() async {
    if (_rendering || _pages.length < 2) {
      return;
    }

    final int before = _page;
    final List<int>? order = await PageOrderSheet.show(
      context,
      thumbnails: <ImageProvider>[
        for (final String path in _pages) pageImage(path, cacheWidth: 102),
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
      _captures = <String>[for (final int i in order) _captures[i]];
      _quads = <CropQuad>[for (final int i in order) _quads[i]];
      _presets = <ScanPreset>[for (final int i in order) _presets[i]];
      _pages = <String>[for (final int i in order) _pages[i]];
      _page = order.indexOf(before);
    });
    _controller.jumpToPage(_page);
  }

  bool get _ready => !_rendering && _pages.every((String p) => p.isNotEmpty);

  /// Leaves the preview, but only after the user confirms that the pages — and
  /// the crop and filter work already done on them — can go.
  Future<void> _cancel() async {
    final bool discard = await confirmDiscard(
      context,
      title: 'Discard this scan?',
      message:
          'The pages have not been saved to your library. '
          'Leaving now throws them away.',
      discardLabel: 'Discard scan',
      keepLabel: 'Keep editing',
    );
    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      PreviewResult(
        presets: List<ScanPreset>.from(_presets),
        quality: _quality,
        pagePaths: List<String>.from(_pages),
        captures: List<String>.from(_captures),
        quads: List<CropQuad>.from(_quads),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(_p),
      child: Builder(
        builder: (BuildContext context) => PopScope(
          // Back out of the preview is the same decision as the close button:
          // the pages are not saved yet, so it asks first.
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              _cancel();
            }
          },
          child: Scaffold(
            backgroundColor: _p.bg,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _header(),
                  ToraRule(),
                  Expanded(child: _pagesView()),
                  if (_rendering) _progress(),
                  PresetBar(
                    selected: _presets[_page],
                    enabled: !_rendering,
                    onSelected: _choosePreset,
                    onApplyAll: _pages.length > 1 && !_rendering
                        ? _applyPresetToAll
                        : null,
                  ),
                  _qualityBar(),
                  _confirmBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final bool busy = _rendering;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _cancel,
            tooltip: 'Back',
            icon: Icon(Icons.close, size: 22, color: _p.ink),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ToraLabel('Final preview', color: _p.ink),
                ToraMicro(
                  'Page ${_page + 1} of ${_pages.length}',
                  color: _p.inkFaint,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : _editCrop,
            tooltip: 'Crop page',
            icon: Icon(
              Icons.crop_rounded,
              size: 20,
              color: busy ? _p.inkFaint : _p.ink,
            ),
          ),
          if (_pages.length > 1)
            IconButton(
              onPressed: busy ? null : _openReorder,
              tooltip: 'Reorder pages',
              icon: Icon(
                Icons.swap_vert_rounded,
                size: 20,
                color: busy ? _p.inkFaint : _p.ink,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pagesView() {
    return PageView.builder(
      controller: _controller,
      itemCount: _pages.length,
      onPageChanged: (int index) => setState(() => _page = index),
      itemBuilder: (BuildContext context, int index) {
        final String path = _pages[index];
        if (path.isEmpty) {
          return Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: _p.accent),
          );
        }

        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image(image: pageImage(path), gaplessPlayback: true),
          ),
        );
      },
    );
  }

  Widget _progress() {
    final int done = _pages.where((String p) => p.isNotEmpty).length;
    final String label = _partial
        ? 'Rendering page ${_page + 1}'
        : 'Rendering ${(done + 1).clamp(1, _pages.length)} of '
              '${_pages.length}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: _p.accent),
          ),
          const SizedBox(width: 10),
          ToraMicro(label, color: _p.inkFaint),
        ],
      ),
    );
  }

  Widget _qualityBar() {
    return Container(
      color: _p.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 10, 6),
      child: Row(
        children: <Widget>[
          ToraMicro('Save quality', color: _p.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _quality.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: toraType(
                10,
                FontWeight.w500,
                color: _p.inkFaint,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _rendering ? null : _chooseQuality,
            style: TextButton.styleFrom(
              foregroundColor: _p.ink,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.compress,
              size: 15,
              color: _rendering ? _p.inkFaint : _p.ink,
            ),
            label: Text(
              _quality.label.toUpperCase(),
              style: toraType(
                10,
                FontWeight.w700,
                tracking: 1.1,
                color: _rendering ? _p.inkFaint : _p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmBar() {
    return Container(
      color: _p.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _ready ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: _p.accent,
            foregroundColor: _p.onAccent,
            disabledBackgroundColor: _p.lineStrong,
            disabledForegroundColor: _p.inkFaint,
            shape: RoundedRectangleBorder(borderRadius: ToraShape.tag),
          ),
          child: Text(
            'SAVE AS PDF',
            style: toraType(
              11,
              FontWeight.w800,
              tracking: 1.4,
              color: _ready ? _p.onAccent : _p.inkFaint,
            ),
          ),
        ),
      ),
    );
  }

  /// True when [order] actually moves something.
  static bool _moved(List<int> order) {
    for (int i = 0; i < order.length; i++) {
      if (order[i] != i) {
        return true;
      }
    }
    return false;
  }

  /// The crop screen hands back the quad it was given when nothing was dragged,
  /// so an untouched trip through it must not trigger a re-render.
  static bool _sameCrop(CropQuad a, CropQuad b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.quarterTurns != b.quarterTurns) {
      return false;
    }
    for (int i = 0; i < 8; i++) {
      if ((a.values[i] - b.values[i]).abs() > 1e-6) {
        return false;
      }
    }
    return true;
  }
}

/// The compression chooser: four steps, each with what it is good for.
///
/// The wording avoids pegging a step to a megabyte count, because the same
/// page can be text on white (tiny) or a photo (large); the description says
/// the trade-off instead of promising a number the file may not hit.
class _QualitySheet extends StatelessWidget {
  const _QualitySheet({required this.selected});

  final SaveQuality selected;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ToraLabel('Save quality', color: p.ink),
            const SizedBox(height: 6),
            Text(
              'Pages are downscaled with an area average, then encoded. '
              'The untouched capture stays in the library either way.',
              style: toraType(11, FontWeight.w500, color: p.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            const ToraRule(),
            for (final SaveQuality quality in SaveQuality.values)
              _QualityRow(
                quality: quality,
                selected: quality == selected,
                onTap: () => Navigator.pop(context, quality),
              ),
          ],
        ),
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.quality,
    required this.selected,
    required this.onTap,
  });

  final SaveQuality quality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: ToraShape.tag,
                border: Border.all(
                  color: selected ? p.accent : p.lineStrong,
                  width: ToraShape.stroke,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 15, color: p.accent)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    quality.label,
                    style: toraType(13, FontWeight.w700, color: p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    quality.description,
                    style: toraType(10, FontWeight.w500, color: p.inkSoft),
                  ),
                ],
              ),
            ),
            Text(
              '${quality.maxEdge} px',
              style: toraType(
                10,
                FontWeight.w600,
                tracking: 0.8,
                color: p.inkFaint,
                tabular: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
