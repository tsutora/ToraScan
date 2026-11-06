import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/crop_quad.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/tora_widgets.dart';
import 'crop_geometry.dart';

/// Eight-point crop editor.
///
/// The four corner handles move a single corner. The four mid-edge handles move
/// *both* corners of their edge by the same delta, so an edge slides as a whole
/// instead of deforming — the behaviour that was missing from the stock
/// scanner UI.
///
/// The quad is stored in normalized coordinates and converted to a real
/// perspective transform when the page is rendered, so dragging a corner out of
/// square still produces a rectangular page.
///
/// Like the editor, this screen is a dark room regardless of the app theme.
class CropScreen extends StatefulWidget {
  const CropScreen({
    super.key,
    required this.pages,
    required this.initialQuads,
    this.title = 'Adjust edges',
    this.doneLabel = 'Looks good',
  });

  final List<String> pages;
  final List<CropQuad> initialQuads;
  final String title;
  final String doneLabel;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  /// Dark regardless of the app theme, in the selected family's dark colours.
  ToraPalette get _p => ToraThemeScope.of(context).family.dark;
  static const double _edgeInset = 30;

  late final List<CropQuad> _quads;
  final List<Size> _sizes = <Size>[];
  int _page = 0;
  int? _activeHandle;
  Rect _imageRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _quads = List<CropQuad>.from(widget.initialQuads);
    while (_quads.length < widget.pages.length) {
      _quads.add(CropQuad.full());
    }
    _resolveSizes();
  }

  Future<void> _resolveSizes() async {
    for (final String path in widget.pages) {
      final Size size = await _sizeOf(path);
      if (!mounted) {
        return;
      }
      setState(() => _sizes.add(size));
    }
  }

  /// The provider the canvas paints. Decoding at screen size instead of the
  /// page's full 1200–2400 px keeps memory flat and the first paint quick.
  static ImageProvider _provider(String path) =>
      ResizeImage(FileImage(File(path)), width: _decodeWidth);

  /// Long edge the crop preview is decoded at. Enough for a phone screen at
  /// 3x, far less memory than a 2400 px page.
  static const int _decodeWidth = 1440;

  /// Measuring only needs the shape, so it decodes at thumbnail size and the
  /// result is dropped immediately. A batch of ten pages therefore does not
  /// pull ten full-resolution frames into the image cache before the first
  /// one is even shown.
  static const int _measureWidth = 96;

  static Future<Size> _sizeOf(String path) async {
    final Completer<Size> completer = Completer<Size>();
    final ImageProvider probe = ResizeImage(
      FileImage(File(path)),
      width: _measureWidth,
    );
    final ImageStream stream = probe.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronous) {
        if (!completer.isCompleted) {
          completer.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          );
        }
        stream.removeListener(listener);
        probe.evict();
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.complete(const Size(1, 1));
        }
        stream.removeListener(listener);
        probe.evict();
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _activeHandle = CropGeometry.hitTest(
        _quads[_page],
        _imageRect,
        details.localPosition,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final int? handle = _activeHandle;
    if (handle == null || _imageRect.isEmpty) {
      return;
    }

    final double dx = details.delta.dx / _imageRect.width;
    final double dy = details.delta.dy / _imageRect.height;
    final CropQuad next = _quads[_page].moveCorners(
      CropGeometry.cornersForHandle(handle),
      dx,
      dy,
    );

    if (CropGeometry.isSane(next)) {
      setState(() => _quads[_page] = next);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _activeHandle = null);
  }

  /// Turns the page a quarter turn. The crop turns with it, so the edges stay
  /// on the same piece of paper.
  void _rotate({required bool clockwise}) {
    setState(() {
      _activeHandle = null;
      _quads[_page] = clockwise
          ? _quads[_page].rotatedCw()
          : _quads[_page].rotatedCcw();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _sizes.length == widget.pages.length;

    return Theme(
      data: AppTheme.dark(_p),
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: _p.bg,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _header(context),
                Expanded(
                  child: ready
                      ? _canvas()
                      : const Center(child: CircularProgressIndicator()),
                ),
                _footer(context, ready),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            color: _p.ink,
            tooltip: 'Cancel',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ToraLabel(widget.title, color: _p.ink),
                const SizedBox(height: 3),
                ToraMicro(
                  widget.pages.length > 1
                      ? 'Page ${_page + 1} of ${widget.pages.length} · '
                            'drag a corner or an edge'
                      : 'Drag a corner, or an edge to slide it',
                  color: _p.inkFaint,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _quads[_page] = CropQuad.full()),
            style: TextButton.styleFrom(
              foregroundColor: _p.inkSoft,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    final int turns = _quads[_page].quarterTurns;
    final Size source = _sizes[_page];
    // A quarter turn swaps the page's width and height on screen.
    final Size imageSize = turns.isOdd
        ? Size(source.height, source.width)
        : source;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boxWidth = math.max(
          1,
          constraints.maxWidth - _edgeInset * 2,
        );
        final double boxHeight = math.max(
          1,
          constraints.maxHeight - _edgeInset * 2,
        );

        final double scale = math.min(
          boxWidth / imageSize.width,
          boxHeight / imageSize.height,
        );
        final double width = imageSize.width * scale;
        final double height = imageSize.height * scale;

        _imageRect = Rect.fromLTWH(
          _edgeInset + (boxWidth - width) / 2,
          _edgeInset + (boxHeight - height) / 2,
          width,
          height,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            children: <Widget>[
              Positioned.fromRect(
                rect: _imageRect,
                child: RotatedBox(
                  quarterTurns: turns,
                  child: Image(
                    image: _provider(widget.pages[_page]),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CropPainter(
                    quad: _quads[_page],
                    imageRect: _imageRect,
                    activeHandle: _activeHandle,
                    palette: _p,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _footer(BuildContext context, bool ready) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _RotateButton(
                icon: Icons.rotate_left,
                label: 'Left',
                onPressed: () => _rotate(clockwise: false),
              ),
              const SizedBox(width: 10),
              _RotateButton(
                icon: Icons.rotate_right,
                label: 'Right',
                onPressed: () => _rotate(clockwise: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.pages.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: _page == 0
                      ? null
                      : () => setState(() => _page -= 1),
                  icon: const Icon(Icons.chevron_left, size: 20),
                  color: _p.ink,
                  disabledColor: _p.inkFaint,
                ),
                ToraMicro(
                  '${_page + 1} / ${widget.pages.length}',
                  color: _p.inkSoft,
                ),
                IconButton(
                  onPressed: _page == widget.pages.length - 1
                      ? null
                      : () => setState(() => _page += 1),
                  icon: const Icon(Icons.chevron_right, size: 20),
                  color: _p.ink,
                  disabledColor: _p.inkFaint,
                ),
              ],
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ready ? () => Navigator.of(context).pop(_quads) : null,
              icon: const Icon(Icons.check, size: 18),
              label: Text(widget.doneLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two turn buttons under the page.
class _RotateButton extends StatelessWidget {
  const _RotateButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraThemeScope.of(context).family.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: ToraShape.tag,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: ToraShape.tag,
            border: Border.all(color: p.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: p.ink),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: toraType(
                  10,
                  FontWeight.w700,
                  tracking: 1.1,
                  color: p.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.quad,
    required this.imageRect,
    required this.activeHandle,
    required this.palette,
  });

  final CropQuad quad;
  final Rect imageRect;
  final int? activeHandle;
  final ToraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> handles = CropGeometry.screenHandles(quad, imageRect);
    final List<Offset> corners = handles.sublist(0, CropGeometry.cornerCount);

    final Path quadPath = Path()..addPolygon(corners, true);

    // Dim everything outside the crop so the kept region stands out.
    final Path scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      quadPath,
    );
    canvas.drawPath(scrim, Paint()..color = const Color(0x8C000000));

    canvas.drawPath(
      quadPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ToraShape.strokeStrong
        ..color = palette.ink,
    );

    // Rule-of-thirds guides, interpolated along the quad's own edges.
    final Paint gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ToraShape.stroke
      ..color = palette.ink.withValues(alpha: 0.28);
    for (int i = 1; i < 3; i++) {
      final double t = i / 3;
      canvas.drawLine(
        Offset.lerp(corners[0], corners[1], t)!,
        Offset.lerp(corners[3], corners[2], t)!,
        gridPaint,
      );
      canvas.drawLine(
        Offset.lerp(corners[0], corners[3], t)!,
        Offset.lerp(corners[1], corners[2], t)!,
        gridPaint,
      );
    }

    for (int i = 0; i < CropGeometry.handleCount; i++) {
      final bool isCorner = i < CropGeometry.cornerCount;
      final Offset point = handles[i];
      final bool active = i == activeHandle;
      final double side = (isCorner ? 12.0 : 10.0) + (active ? 3 : 0);

      final RRect handle = RRect.fromRectAndRadius(
        Rect.fromCenter(center: point, width: side, height: side),
        const Radius.circular(ToraShape.rTag),
      );

      // A dark keyline keeps both handle fills readable on white paper and on
      // the dimmed area outside the crop.
      canvas.drawRRect(
        handle.inflate(1),
        Paint()..color = const Color(0xCC0F1113),
      );
      canvas.drawRRect(
        handle,
        Paint()..color = isCorner ? palette.accent : palette.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.quad != quad ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.activeHandle != activeHandle ||
      oldDelegate.palette != palette;
}
