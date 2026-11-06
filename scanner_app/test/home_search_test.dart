import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_document.dart';
import 'package:scanner_app/models/scan_folder.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/screens/folder_screen.dart';
import 'package:scanner_app/screens/home_screen.dart';
import 'package:scanner_app/services/scan_store.dart';
import 'package:scanner_app/services/storage_service.dart';
import 'package:scanner_app/theme/app_theme.dart';
import 'package:scanner_app/widgets/no_matches.dart';
import 'package:scanner_app/widgets/search_field.dart';

/// A phone-sized surface over a throwaway documents directory, so the screens
/// load a library exactly as they would on a phone.
Directory _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final Directory temp = Directory.systemTemp.createTempSync('torascan_search_');
  addTearDown(() {
    try {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    } catch (_) {
      // A pending write on Windows can hold the directory briefly.
    }
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => temp.path,
      );
  return temp;
}

ScanDocument _doc(String title, int day, {String? folderId}) => ScanDocument(
  id: 'doc-$day',
  title: title,
  // The thumbnail does not need to exist; the tile draws its placeholder.
  pagePaths: <String>['$title.jpg'],
  originalPaths: <String>['$title.jpg'],
  pagePresets: <ScanPreset>[ScanPreset.auto],
  pdfPath: '$title.pdf',
  createdAt: DateTime(2026, 11, day),
  folderId: folderId,
);

/// Writes two scans, then shows [home]. Returns the store so a folder screen
/// can be opened over the same library.
Future<ScanStore> _openHome(WidgetTester tester) async {
  _phone(tester);
  late ScanStore store;

  await tester.runAsync(() async {
    store = ScanStore();
    await store.add(_doc('Kwitansi Sewa Kendaraan Oktober 2026', 3));
    await store.add(_doc('Uji Mutu', 2));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const HomeScreen(storageMode: StorageMode.private),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
  });
  await tester.pump();

  return store;
}

/// Writes a folder with one scan in it, plus an unfiled scan, and opens it.
Future<void> _openFolder(WidgetTester tester) async {
  _phone(tester);
  late ScanStore store;
  late ScanFolder folder;

  await tester.runAsync(() async {
    store = ScanStore();
    folder = ScanFolder(
      id: 'folder-1',
      name: 'Uji mutu',
      createdAt: DateTime(2026, 11, 1),
    );
    await store.addFolder(folder);
    await store.add(_doc('Uji Mutu 29 Oct', 4, folderId: folder.id));
    await store.add(_doc('Kwitansi Sewa', 3));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FolderScreen(folder: folder, store: store),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
  });
  await tester.pump();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.tap(find.byIcon(Icons.search));
  await tester.pump();
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

void main() {
  testWidgets('the library searches by scan name', (WidgetTester tester) async {
    await _openHome(tester);

    expect(find.text('Kwitansi Sewa Kendaraan Oktober 2026'), findsOneWidget);
    expect(find.text('Uji Mutu'), findsOneWidget);
    expect(find.text('ALL SCANS'), findsOneWidget);

    await _search(tester, 'kwitansi okt');

    // Results replace the library, and the folder strip steps aside.
    expect(find.text('RESULTS'), findsOneWidget);
    expect(find.text('1 OF 2'), findsOneWidget);
    expect(find.text('Kwitansi Sewa Kendaraan Oktober 2026'), findsOneWidget);
    expect(find.text('Uji Mutu'), findsNothing);
    expect(find.text('FOLDERS'), findsNothing);
  });

  testWidgets('a query that matches nothing says so and offers a way back', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await _search(tester, 'invoice');

    expect(find.byType(NoMatches), findsOneWidget);
    expect(find.textContaining('No scan is named'), findsOneWidget);

    await tester.tap(find.text('CLEAR SEARCH'));
    await tester.pump();

    expect(find.byType(NoMatches), findsNothing);
    expect(find.text('2 OF 2'), findsOneWidget);
    expect(find.text('Uji Mutu'), findsOneWidget);
  });

  testWidgets('cancelling the search restores the whole library', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await _search(tester, 'uji');
    expect(find.text('Uji Mutu'), findsOneWidget);
    expect(find.text('Kwitansi Sewa Kendaraan Oktober 2026'), findsNothing);

    await tester.tap(find.text('CANCEL'));
    await tester.pump();

    expect(find.byType(ToraSearchField), findsNothing);
    expect(find.text('ALL SCANS'), findsOneWidget);
    expect(find.text('Kwitansi Sewa Kendaraan Oktober 2026'), findsOneWidget);
    expect(find.text('Uji Mutu'), findsOneWidget);
  });

  testWidgets('back closes the search instead of offering to exit', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await _search(tester, 'uji');

    // What Android sends when the back gesture is used.
    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      message,
      (ByteData? _) {},
    );
    await tester.pumpAndSettle();

    expect(find.text('Exit ToraScan?'), findsNothing);
    expect(find.byType(ToraSearchField), findsNothing);
    expect(find.text('Kwitansi Sewa Kendaraan Oktober 2026'), findsOneWidget);
  });

  testWidgets('a folder searches only the scans inside it', (
    WidgetTester tester,
  ) async {
    await _openFolder(tester);

    // The unfiled scan is in the library, but not in this folder.
    expect(find.text('Uji Mutu 29 Oct'), findsOneWidget);
    expect(find.text('Kwitansi Sewa'), findsNothing);

    await _search(tester, 'kwitansi');

    expect(find.byType(NoMatches), findsOneWidget);
    expect(find.text('Uji Mutu 29 Oct'), findsNothing);

    await tester.tap(find.text('CLEAR SEARCH'));
    await tester.pump();
    expect(find.text('Uji Mutu 29 Oct'), findsOneWidget);
  });
}
