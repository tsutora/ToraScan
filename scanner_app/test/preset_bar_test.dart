import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/theme/theme_controller.dart';
import 'package:scanner_app/widgets/preset_bar.dart';

Widget _host({
  required ScanPreset selected,
  required ValueChanged<ScanPreset> onSelected,
  bool enabled = true,
  VoidCallback? onApplyAll,
}) {
  return ToraThemeScope(
    controller: ThemeController(),
    child: MaterialApp(
      home: Scaffold(
        body: PresetBar(
          selected: selected,
          enabled: enabled,
          onSelected: onSelected,
          onApplyAll: onApplyAll,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every filter is offered, in order', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(selected: ScanPreset.auto, onSelected: (_) {}),
    );

    for (final ScanPreset preset in ScanPreset.values) {
      expect(
        find.text(preset.label.toUpperCase()),
        findsOneWidget,
        reason: '${preset.label} should be reachable',
      );
    }
  });

  testWidgets('tapping a filter reports it', (WidgetTester tester) async {
    ScanPreset? chosen;
    await tester.pumpWidget(
      _host(
        selected: ScanPreset.auto,
        onSelected: (ScanPreset preset) => chosen = preset,
      ),
    );

    await tester.tap(find.text('GRAY'));
    await tester.pump();

    expect(chosen, ScanPreset.grayscale);
  });

  testWidgets('APPLY TO ALL is offered for multi-page sets only', (
    WidgetTester tester,
  ) async {
    // A phone-width surface: the five tags alone fill the row, so the action
    // must not be pushed off the end of the scroller.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(selected: ScanPreset.auto, onSelected: (_) {}),
    );
    expect(find.text('APPLY TO ALL'), findsNothing);

    int applied = 0;
    await tester.pumpWidget(
      _host(
        selected: ScanPreset.auto,
        onSelected: (_) {},
        onApplyAll: () => applied++,
      ),
    );

    final Rect rect = tester.getRect(find.text('APPLY TO ALL'));
    expect(rect.right, lessThanOrEqualTo(360));

    await tester.tap(find.text('APPLY TO ALL'));
    await tester.pump();

    expect(applied, 1);
  });

  testWidgets('the bar ignores taps while a page is rendering', (
    WidgetTester tester,
  ) async {
    ScanPreset? chosen;
    await tester.pumpWidget(
      _host(
        selected: ScanPreset.auto,
        enabled: false,
        onSelected: (ScanPreset preset) => chosen = preset,
      ),
    );

    await tester.tap(find.text('GRAY'));
    await tester.pump();

    // A filter change mid-render would fight the one already in flight.
    expect(chosen, isNull);
  });
}
