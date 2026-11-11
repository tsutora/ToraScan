import 'package:flutter/material.dart';

import '../app_info.dart';
import '../theme/app_theme.dart';
import '../theme/palettes.dart';
import '../theme/theme_controller.dart';
import '../theme/tora_widgets.dart';

/// The appearance sidebar, opened by tapping the monogram.
///
/// Two decisions, both saved: the brightness, and which pastel family to use.
/// Every family carries a light and a dark set, so switching brightness never
/// loses the chosen colour.
class ThemeDrawer extends StatelessWidget {
  const ThemeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);
    final ThemeController controller = ToraThemeScope.of(context);

    return Drawer(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: <Widget>[
                  const ToraMonogram(size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ToraLabel('ToraScan', color: p.ink),
                      const ToraMicro('Appearance'),
                    ],
                  ),
                ],
              ),
            ),
            ToraRule(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: <Widget>[
                  const ToraLabel('Brightness'),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      for (final ThemeMode mode in <ThemeMode>[
                        ThemeMode.system,
                        ThemeMode.light,
                        ThemeMode.dark,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ModeChip(
                            mode: mode,
                            selected: controller.mode == mode,
                            onTap: () => controller.setMode(mode),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const ToraLabel('Theme'),
                  const SizedBox(height: 6),
                  for (final ToraPaletteFamily family in ToraPalettes.all)
                    _FamilyRow(
                      family: family,
                      selected: controller.family.id == family.id,
                      onTap: () => controller.setFamily(family),
                    ),
                ],
              ),
            ),
            ToraRule(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: ToraMicro('Version $toraVersion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Material(
      color: selected ? p.accent : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: ToraShape.tag,
        side: BorderSide(
          color: selected ? p.accent : p.lineStrong,
          width: ToraShape.stroke,
        ),
      ),
      child: InkWell(
        borderRadius: ToraShape.tag,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            _label(mode),
            style: toraType(
              10,
              FontWeight.w700,
              tracking: 1.2,
              color: selected ? p.onAccent : p.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  static String _label(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'SYSTEM';
      case ThemeMode.light:
        return 'LIGHT';
      case ThemeMode.dark:
        return 'DARK';
    }
  }
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final ToraPaletteFamily family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: <Widget>[
            _Swatch(palette: family.light),
            const SizedBox(width: 4),
            _Swatch(palette: family.dark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                family.label,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: selected ? p.accentText : p.ink),
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }
}

/// A 24px tile of one palette: its background, a hairline, and its accent.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final ToraPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: ToraShape.tag,
        border: Border.all(color: palette.lineStrong, width: ToraShape.stroke),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
