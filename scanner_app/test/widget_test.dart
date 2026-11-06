import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/main.dart';
import 'package:scanner_app/models/scan_document.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/screens/home_screen.dart';
import 'package:scanner_app/services/share_service.dart';
import 'package:scanner_app/theme/palettes.dart';
import 'package:scanner_app/theme/tora_widgets.dart';

/// Pumps the real app at a phone-sized surface, since the storage gate lays
/// itself out for one and the default 800x600 test window is not a phone.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ToraScanApp());
  await tester.pump();
}

/// Points `path_provider` at a throwaway directory so the real file I/O in the
/// library and the theme store can run inside a widget test.
Directory _useTempDocuments() {
  final Directory temp = Directory.systemTemp.createTempSync('torascan_test_');
  addTearDown(() {
    try {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    } catch (_) {
      // A pending write on Windows can hold the directory briefly; the OS
      // cleans the temp folder up later.
    }
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => temp.path,
      );
  return temp;
}

void main() {
  testWidgets('the app is branded ToraScan', (WidgetTester tester) async {
    await _pumpApp(tester);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.title, 'ToraScan');
  });

  testWidgets('first run says where the library will live', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Grant access'), findsOneWidget);
    expect(find.text('Use private storage instead'), findsOneWidget);
    // The gate names the real folder before asking for anything.
    expect(find.text('/storage/emulated/0/ToraScan'), findsOneWidget);
  });

  testWidgets('declining access still opens a working library', (
    WidgetTester tester,
  ) async {
    _useTempDocuments();

    await tester.runAsync(() async {
      await _pumpApp(tester);
      await tester.tap(find.text('Use private storage instead'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    // No marketing headline any more — just the library.
    expect(find.text('ALL SCANS'), findsOneWidget);
    expect(find.text('SCAN'), findsOneWidget);
    expect(find.text('Nothing scanned yet'), findsOneWidget);
  });

  testWidgets('the monogram opens the theme sidebar', (
    WidgetTester tester,
  ) async {
    _useTempDocuments();

    await tester.runAsync(() async {
      await _pumpApp(tester);
      await tester.tap(find.text('Use private storage instead'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    await tester.tap(find.byType(ToraMonogram).first);
    await tester.pumpAndSettle();

    expect(find.text('BRIGHTNESS'), findsOneWidget);
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('Mint'), findsOneWidget);

    await tester.tap(find.text('Mint'));
    // Let the preference write finish before the temp directory is removed.
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.theme?.scaffoldBackgroundColor, ToraPalettes.mint.light.bg);
  });

  testWidgets('the mode sheet offers two camera modes and PDF import', (
    WidgetTester tester,
  ) async {
    _useTempDocuments();

    await tester.runAsync(() async {
      await _pumpApp(tester);
      await tester.tap(find.text('Use private storage instead'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    await tester.tap(find.text('SCAN'));
    await tester.pumpAndSettle();

    expect(find.text('Single page'), findsOneWidget);
    expect(find.text('Batch'), findsOneWidget);
    expect(find.text('Import PDF'), findsOneWidget);
    // The explanatory lines were removed: the rows are icon + title only.
    expect(find.text('One shot, then the crop'), findsNothing);
    expect(
      find.text('Stay in the camera · tap Done when finished'),
      findsNothing,
    );

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
  });

  testWidgets('system back asks before closing the app', (
    WidgetTester tester,
  ) async {
    _useTempDocuments();

    await tester.runAsync(() async {
      await _pumpApp(tester);
      await tester.tap(find.text('Use private storage instead'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    // What Android sends when the back gesture is used on the root route.
    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      message,
      (ByteData? _) {},
    );
    await tester.pumpAndSettle();

    expect(find.text('Exit ToraScan?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Still here: cancelling must not close the library.
    expect(find.text('Exit ToraScan?'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  test('every palette family is reachable by id', () {
    final Set<String> ids = <String>{};
    for (final ToraPaletteFamily family in ToraPalettes.all) {
      ids.add(family.id);
      expect(ToraPalettes.byId(family.id), same(family));
    }
    expect(ids, hasLength(ToraPalettes.all.length));
    expect(ToraPalettes.byId('missing'), same(ToraPalettes.neutral));
  });

  test('JPG pages are named after the document', () async {
    final Directory temp = _useTempDocuments();
    final Directory pages = Directory(
      '${temp.path}${Platform.pathSeparator}pages',
    )..createSync();

    final List<String> paths = <String>[];
    for (int i = 0; i < 2; i++) {
      final File file = File(
        '${pages.path}${Platform.pathSeparator}page_0$i.jpg',
      )..writeAsBytesSync(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
      paths.add(file.path);
    }

    final ScanDocument doc = ScanDocument(
      id: 'doc1',
      title: 'Receipt: March',
      pagePaths: paths,
      originalPaths: List<String>.from(paths),
      pagePresets: List<ScanPreset>.filled(2, ScanPreset.none),
      pdfPath: '${temp.path}${Platform.pathSeparator}doc.pdf',
      createdAt: DateTime(2026, 1, 1),
    );

    final List<String> names = (await ShareService.jpgFiles(doc))
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList();

    expect(names, <String>['Receipt_ March 01.jpg', 'Receipt_ March 02.jpg']);
  });
}
