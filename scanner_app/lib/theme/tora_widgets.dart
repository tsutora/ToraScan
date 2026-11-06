import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The design-system primitives from `design.md`, as widgets.
///
/// These exist so every screen draws the same monogram, rule, tag and stat
/// block instead of re-deriving them from hex values.

/// The Tora mark, from the logo deck: a black app tile, a big white `T`, and
/// one small orange tool icon tucked beside the stem.
///
/// The three layers are locked in that order (tile → tool → `T`) and the
/// geometry is the deck's own, so the in-app mark and the launcher icon are the
/// same drawing at different sizes. Below 32 px the tool is dropped, exactly as
/// the deck's minimum-size rule says.
///
/// [outline] is the light variant used for large decorative placements: no
/// tile fill, a hairline border, and the letter in the palette's ink.
class ToraMonogram extends StatelessWidget {
  const ToraMonogram({super.key, this.size = 32, this.outline = false});

  final double size;
  final bool outline;

  /// The locked mark colours. They do not follow the app palette: the tile is
  /// the app icon, and an icon that changes colour with a theme is not an icon.
  static const Color tile = Color(0xFF0A0A0B);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color signal = Color(0xFFFF7A4E);

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ToraMarkPainter(
          tile: outline ? null : tile,
          letter: outline ? p.ink : paper,
          tool: outline ? p.accent : signal,
          border: outline ? p.lineStrong : null,
        ),
      ),
    );
  }
}

class _ToraMarkPainter extends CustomPainter {
  const _ToraMarkPainter({
    required this.tile,
    required this.letter,
    required this.tool,
    required this.border,
  });

  final Color? tile;
  final Color letter;
  final Color tool;
  final Color? border;

  /// The deck draws the mark on a 100 × 100 grid; everything below is in those
  /// units and scaled once to the widget's size.
  static final RRect _tileBox = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, 100, 100),
    const Radius.circular(22),
  );

  static final RRect _sheet = RRect.fromRectAndRadius(
    const Rect.fromLTWH(67, 50, 14, 18),
    const Radius.circular(2),
  );

  static final Path _letterT = Path()
    ..moveTo(22, 26)
    ..lineTo(78, 26)
    ..lineTo(78, 42)
    ..lineTo(58, 42)
    ..lineTo(58, 78)
    ..lineTo(42, 78)
    ..lineTo(42, 42)
    ..lineTo(22, 42)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.width / 100;
    canvas.save();
    canvas.scale(unit, unit);

    if (tile != null) {
      canvas.drawRRect(_tileBox, Paint()..color = tile!);
    }
    if (border != null) {
      canvas.drawRRect(
        _tileBox.deflate(0.75),
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Layer 2 — the tool. Only beside the stem, and only where it stays
    // legible: under 32 px the deck ships the bare T.
    if (size.width >= 32) {
      final Paint toolPaint = Paint()
        ..color = tool
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.butt;
      canvas.drawRRect(_sheet, toolPaint);
      canvas.drawLine(const Offset(63, 60), const Offset(85, 60), toolPaint);
    }

    // Layer 3 — the T, always in front.
    canvas.drawPath(_letterT, Paint()..color = letter);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToraMarkPainter oldDelegate) =>
      oldDelegate.tile != tile ||
      oldDelegate.letter != letter ||
      oldDelegate.tool != tool ||
      oldDelegate.border != border;
}

/// Uppercase section label, `label` role: 700, +0.14em.
class ToraLabel extends StatelessWidget {
  const ToraLabel(this.text, {super.key, this.color, this.size = 11});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Text(
      text.toUpperCase(),
      style: toraType(
        size,
        FontWeight.w700,
        tracking: size * 0.14,
        height: 1.2,
        color: color ?? p.inkSoft,
      ),
    );
  }
}

/// Uppercase metadata, `micro` role: 600, +0.12em, faint.
///
/// [upper] is off for strings that must keep their own case — a filesystem
/// path, for instance, where upper-casing would misreport the real name.
///
/// [maxLines] clamps the line count and ellipsizes instead. Rows that hold a
/// variable-width label beside fixed chrome use it so a long status never
/// pushes the row wider than the screen.
class ToraMicro extends StatelessWidget {
  const ToraMicro(
    this.text, {
    super.key,
    this.color,
    this.size = 10,
    this.upper = true,
    this.maxLines,
  });

  final String text;
  final Color? color;
  final double size;
  final bool upper;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Text(
      upper ? text.toUpperCase() : text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: toraType(
        size,
        FontWeight.w600,
        tracking: size * 0.12,
        height: 1.25,
        color: color ?? p.inkFaint,
      ),
    );
  }
}

/// A hairline, or the single accent rule (3 × 64).
class ToraRule extends StatelessWidget {
  const ToraRule({super.key, this.accent = false, this.width = 64});

  final bool accent;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    if (accent) {
      return Container(width: width, height: 3, color: p.accent);
    }
    return Container(
      width: double.infinity,
      height: ToraShape.stroke,
      color: p.line,
    );
  }
}

/// A 2px-radius uppercase tag. [signal] fills it with the accent.
class ToraTag extends StatelessWidget {
  const ToraTag(this.text, {super.key, this.signal = false, this.onTap});

  final String text;
  final bool signal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    final Widget tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: signal ? p.accent : Colors.transparent,
        borderRadius: ToraShape.tag,
        border: Border.all(
          color: signal ? p.accent : p.lineStrong,
          width: ToraShape.stroke,
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: toraType(
          9.5,
          FontWeight.w600,
          tracking: 1.2,
          height: 1.3,
          color: signal ? p.onAccent : p.inkSoft,
        ),
      ),
    );

    if (onTap == null) {
      return tag;
    }
    return GestureDetector(onTap: onTap, child: tag);
  }
}

/// Key figure over a label, with the 1px underline from the spec.
class ToraStat extends StatelessWidget {
  const ToraStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: toraType(
            26,
            FontWeight.w800,
            tracking: -0.9,
            height: 1,
            color: p.ink,
            tabular: true,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: ToraShape.stroke, color: p.lineStrong),
        const SizedBox(height: 8),
        ToraLabel(label, size: 9.5),
      ],
    );
  }
}

/// A section heading row: label on the left, optional action on the right.
class ToraSectionHeader extends StatelessWidget {
  const ToraSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.action,
    this.onAction,
    this.secondaryAction,
    this.onSecondaryAction,
  });

  final String label;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  /// A second, quieter action placed left of [action] — e.g. "All" beside
  /// "New" on the folder strip.
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: <Widget>[
          ToraLabel(label, size: 11),
          const Spacer(),
          if (trailing != null) ToraMicro(trailing!, color: p.inkFaint),
          if (secondaryAction != null)
            TextButton(
              onPressed: onSecondaryAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: p.inkSoft,
              ),
              child: Text(secondaryAction!.toUpperCase()),
            ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(action!.toUpperCase()),
            ),
        ],
      ),
    );
  }
}
