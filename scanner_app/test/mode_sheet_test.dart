import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_mode.dart';
import 'package:scanner_app/services/scan_flow.dart';
import 'package:scanner_app/theme/app_theme.dart';

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => ScanFlow.pickMode(context),
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
  testWidgets('the mode sheet lists both camera modes and PDF import', (
    WidgetTester tester,
  ) async {
    await _openSheet(tester);

    expect(find.text('Single page'), findsOneWidget);
    expect(find.text('Batch'), findsOneWidget);
    expect(find.text('Import PDF'), findsOneWidget);
    // The mode rows carry no explanatory copy under them.
    expect(find.text('One page at a time'), findsNothing);
  });

  testWidgets('Single page returns a camera session', (
    WidgetTester tester,
  ) async {
    ScanStart? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await ScanFlow.pickMode(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Single page'));
    await tester.pumpAndSettle();

    expect(result, isA<CameraScanStart>());
    expect((result! as CameraScanStart).mode, ScanMode.single);
  });

  testWidgets('Batch returns a camera session', (WidgetTester tester) async {
    ScanStart? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await ScanFlow.pickMode(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();

    expect(result, isA<CameraScanStart>());
    expect((result! as CameraScanStart).mode, ScanMode.batch);
  });

  testWidgets('Import PDF returns the PDF choice', (WidgetTester tester) async {
    ScanStart? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await ScanFlow.pickMode(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();

    expect(result, isA<PdfScanStart>());
  });
}
