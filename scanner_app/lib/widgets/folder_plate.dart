import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A card drawn as a folder, not as a rectangle.
///
/// The library strip used to be a grid of bordered squares, which read as
/// "card" rather than "folder". This paints the silhouette instead: a tab on
/// the top-left, a slanted shoulder, and the body below it, all in the deck's
/// hairline stroke. The content is inset below the tab so nothing sits on the
/// outline.
class FolderPlate extends StatelessWidget {
  const FolderPlate({
    super.key,
    required this.child,
    this.onTap,
    this.filled = true,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Filled plates are real folders; an empty plate is the "new folder" slot.
  final bool filled;
  final Color? borderColor;

  /// Height of the tab, measured from the top of the plate.
  static const double tabHeight = 18;

  /// Width of the tab, before the shoulder slants down to the body.
  static const double tabWidth = 58;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return CustomPaint(
      painter: _FolderPainter(
        fill: filled ? p.surface : Colors.transparent,
        stroke: borderColor ?? (filled ? p.line : p.lineStrong),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ToraShape.card,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, tabHeight + 10, 12, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double tab = FolderPlate.tabHeight;
    const double shoulder = 9;

    final Path path = Path()
      ..moveTo(0, h)
      ..lineTo(0, 0)
      ..lineTo(FolderPlate.tabWidth - shoulder, 0)
      ..lineTo(FolderPlate.tabWidth, tab)
      ..lineTo(w, tab)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ToraShape.stroke
        ..color = stroke
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(_FolderPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}
