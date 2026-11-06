import 'package:flutter/material.dart';

import '../models/scan_preset.dart';
import '../theme/app_theme.dart';

/// The filter row: one tag per [ScanPreset], in the deck's voice.
///
/// Kept as a plain row of tags rather than a carousel or a slider because the
/// presets are discrete and few, and the label is the whole affordance — the
/// page above is the preview.
class PresetBar extends StatelessWidget {
  const PresetBar({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.onApplyAll,
  });

  final ScanPreset selected;
  final bool enabled;
  final ValueChanged<ScanPreset> onSelected;

  /// Copies the selected filter to every page. Null hides the action, which is
  /// what a single-page document wants.
  final VoidCallback? onApplyAll;

  @override
  Widget build(BuildContext context) {
    final ToraPalette p = ToraPalette.of(context);

    return Container(
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      // APPLY TO ALL is pinned outside the scroller. On a phone the five tags
      // already fill the width, so a trailing button inside the row would sit
      // off-screen and be undiscoverable until the user thought to swipe.
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final ScanPreset preset in ScanPreset.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(preset.label.toUpperCase()),
                        selected: preset == selected,
                        onSelected: enabled ? (_) => onSelected(preset) : null,
                        labelStyle: toraType(
                          10,
                          FontWeight.w700,
                          tracking: 1.2,
                          color: preset == selected ? p.onAccent : p.inkSoft,
                        ),
                        backgroundColor: p.surface,
                        selectedColor: p.accent,
                        disabledColor: p.surface,
                        side: BorderSide(
                          color: preset == selected ? p.accent : p.lineStrong,
                          width: ToraShape.stroke,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: ToraShape.tag,
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onApplyAll != null) ...<Widget>[
            Container(width: 1, height: 22, color: p.line),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: enabled ? onApplyAll : null,
              style: TextButton.styleFrom(
                foregroundColor: p.ink,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                Icons.copy_all_rounded,
                size: 15,
                color: enabled ? p.ink : p.inkFaint,
              ),
              label: Text(
                'APPLY TO ALL',
                style: toraType(
                  10,
                  FontWeight.w700,
                  tracking: 1.1,
                  color: enabled ? p.ink : p.inkFaint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
