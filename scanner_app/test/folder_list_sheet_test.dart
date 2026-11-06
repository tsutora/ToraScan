import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_folder.dart';
import 'package:scanner_app/theme/app_theme.dart';
import 'package:scanner_app/theme/palettes.dart';
import 'package:scanner_app/widgets/folder_list_sheet.dart';

List<ScanFolder> _folders(int count) => <ScanFolder>[
  for (int i = 0; i < count; i++)
    ScanFolder(
      id: 'folder-$i',
      name: 'Folder ${i + 1}',
      createdAt: DateTime(2026, 11, 2),
    ),
];

/// Pumps a screen whose only button opens the sheet and records its result.
Future<void> _pumpOpener(
  WidgetTester tester, {
  required int folders,
  required void Function(List<int>?) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(
                  await FolderListSheet.show(
                    context,
                    folders: _folders(folders),
                    counts: <int>[for (int i = 0; i < folders; i++) i],
                    palette: ToraPalettes.sand.light,
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
  testWidgets('lists every folder with its scan count', (
    WidgetTester tester,
  ) async {
    await _pumpOpener(tester, folders: 3, onResult: (List<int>? _) {});

    expect(find.text('ALL FOLDERS'), findsOneWidget);
    expect(find.text('Folder 1'), findsOneWidget);
    expect(find.text('Folder 2'), findsOneWidget);
    expect(find.text('Folder 3'), findsOneWidget);
    expect(find.text('2 SCANS'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('DONE returns the untouched order', (WidgetTester tester) async {
    List<int>? result;
    await _pumpOpener(
      tester,
      folders: 3,
      onResult: (List<int>? r) => result = r,
    );

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(result, <int>[0, 1, 2]);
  });

  testWidgets('dragging a handle moves that folder', (
    WidgetTester tester,
  ) async {
    List<int>? result;
    await _pumpOpener(
      tester,
      folders: 2,
      onResult: (List<int>? r) => result = r,
    );

    // Drag the first folder down past the second.
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

  testWidgets('an empty library says so instead of showing a DONE on nothing', (
    WidgetTester tester,
  ) async {
    await _pumpOpener(tester, folders: 0, onResult: (List<int>? _) {});

    expect(find.text('ALL FOLDERS'), findsOneWidget);
    expect(find.textContaining('No folders yet'), findsOneWidget);
    expect(find.text('DONE'), findsNothing);
  });
}
