import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/theme/app_theme.dart';
import 'package:scanner_app/widgets/confirm_dialog.dart';

/// Pumps a screen whose only button opens [open] and records its answer.
Future<void> _pumpOpener(
  WidgetTester tester,
  Future<bool> Function(BuildContext context) open,
  void Function(bool) record,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => record(await open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('keeping the work is the default answer', (
    WidgetTester tester,
  ) async {
    bool? result;
    await _pumpOpener(
      tester,
      (BuildContext context) => confirmDiscard(
        context,
        title: 'Discard changes?',
        message: 'Nothing is saved yet.',
        discardLabel: 'Discard changes',
        keepLabel: 'Keep editing',
      ),
      (bool value) => result = value,
    );

    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('discarding returns true only when asked', (
    WidgetTester tester,
  ) async {
    bool? result;
    await _pumpOpener(
      tester,
      (BuildContext context) => confirmDiscard(
        context,
        title: 'Discard changes?',
        message: 'Nothing is saved yet.',
        discardLabel: 'Discard changes',
        keepLabel: 'Keep editing',
      ),
      (bool value) => result = value,
    );

    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('a save is only committed after the confirm', (
    WidgetTester tester,
  ) async {
    bool? result;
    await _pumpOpener(
      tester,
      (BuildContext context) => confirmSave(
        context,
        title: 'Save changes?',
        message: 'The PDF is rewritten.',
      ),
      (bool value) => result = value,
    );

    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('cancelling the save leaves the file alone', (
    WidgetTester tester,
  ) async {
    bool? result;
    await _pumpOpener(
      tester,
      (BuildContext context) => confirmSave(
        context,
        title: 'Save changes?',
        message: 'The PDF is rewritten.',
      ),
      (bool value) => result = value,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
