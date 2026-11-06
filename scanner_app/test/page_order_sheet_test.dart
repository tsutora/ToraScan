import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/theme/app_theme.dart';
import 'package:scanner_app/widgets/page_order_sheet.dart';

/// A valid 1x1 PNG, so the thumbnails paint instead of throwing.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

List<ImageProvider> _thumbs(int count) => <ImageProvider>[
  for (int i = 0; i < count; i++) MemoryImage(_pixel),
];

/// Pumps a screen with one button that opens the sheet and records its result.
Future<void> _pumpOpener(
  WidgetTester tester, {
  required int pages,
  required void Function(List<int>?) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(
                  await PageOrderSheet.show(
                    context,
                    thumbnails: _thumbs(pages),
                    palette: ToraPalette.dark,
                  ),
                );
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
}

void main() {
  testWidgets('lists one row per page', (WidgetTester tester) async {
    await _pumpOpener(tester, pages: 3, onResult: (_) {});

    expect(find.text('REORDER PAGES'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('DONE returns the untouched order', (WidgetTester tester) async {
    List<int>? result;
    await _pumpOpener(tester, pages: 3, onResult: (List<int>? r) => result = r);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(result, <int>[0, 1, 2]);
  });

  testWidgets('dragging a handle moves that page', (WidgetTester tester) async {
    List<int>? result;
    await _pumpOpener(tester, pages: 2, onResult: (List<int>? r) => result = r);

    // Drag page 1 down past page 2.
    await tester.timedDrag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 120),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(result, <int>[1, 0]);
  });
}
