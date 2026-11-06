import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_document.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/widgets/share_sheet.dart';

/// The sheet is what a user reads right after a scan is saved, so the subtitle
/// has to describe what the app actually does now. Cropping and filters moved
/// to the pre-save preview; the saved document only reads, reorders and shares.
///
/// `ToraMicro` upper-cases its text, so the expectations below are upper-case:
/// they match what is on screen, not what the source string says.
ScanDocument _doc({int pages = 1}) {
  final DateTime now = DateTime(2026, 10, 31, 21, 52);
  return ScanDocument(
    id: 'test',
    title: 'Scan 31 Oct 2026 21.52',
    pagePaths: <String>[for (int i = 1; i <= pages; i++) 'page_$i.jpg'],
    originalPaths: <String>[for (int i = 1; i <= pages; i++) 'orig_$i.jpg'],
    pagePresets: <ScanPreset>[for (int i = 0; i < pages; i++) ScanPreset.auto],
    pdfPath: 'scan.pdf',
    createdAt: now,
  );
}

Widget _host(ScanDocument doc) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: ShareSheet(document: doc)),
);

void main() {
  testWidgets('open-document subtitle describes the saved-document viewer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_doc()));

    expect(find.text('READ · REORDER · PAGES'), findsOneWidget);
    // The old copy promised editing the viewer no longer offers.
    expect(find.text('CROP · PRESET · PAGES'), findsNothing);
  });

  testWidgets('page count is reported for a single page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_doc()));

    expect(find.text('.PDF'), findsOneWidget);
    expect(find.text('.JPG'), findsOneWidget);
    expect(find.text('SAVED · 1 PAGE'), findsOneWidget);
  });

  testWidgets('page count is reported for a batch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_doc(pages: 3)));

    expect(find.text('3 .JPG'), findsOneWidget);
  });
}
