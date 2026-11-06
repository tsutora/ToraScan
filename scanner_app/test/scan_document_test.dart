import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/models/scan_document.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/models/save_quality.dart';

/// A document whose parallel lists are exactly the kind of list the library
/// hands over: a JSON decode's `.cast()` view and a fixed-length `filled`.
ScanDocument _fromStiffLists() {
  final List<dynamic> decoded = <dynamic>['a.jpg', 'b.jpg'];
  return ScanDocument(
    id: 'doc',
    title: 'Doc',
    pagePaths: decoded.cast<String>(),
    originalPaths: decoded.cast<String>(),
    pagePresets: List<ScanPreset>.filled(2, ScanPreset.auto),
    pdfPath: 'doc.pdf',
    createdAt: DateTime(2026, 11, 2),
  );
}

void main() {
  test('lists handed in by the library are copied into growable ones', () {
    final ScanDocument doc = _fromStiffLists();

    // The edits that used to throw "Cannot clear a fixed-length list".
    expect(
      () => doc.pagePaths
        ..clear()
        ..addAll(<String>['a.jpg', 'b.jpg']),
      returnsNormally,
    );
    expect(
      () => doc.pagePresets
        ..clear()
        ..addAll(<ScanPreset>[ScanPreset.auto, ScanPreset.auto]),
      returnsNormally,
    );
    expect(
      () => doc.pageCrops
        ..clear()
        ..addAll(<CropQuad>[CropQuad.full(), CropQuad.full()]),
      returnsNormally,
    );
  });

  test('the document does not share a list with its caller', () {
    final List<String> pages = <String>['a.jpg', 'b.jpg'];
    final ScanDocument doc = ScanDocument(
      id: 'doc',
      title: 'Doc',
      pagePaths: pages,
      originalPaths: pages,
      pagePresets: <ScanPreset>[ScanPreset.auto, ScanPreset.auto],
      pdfPath: 'doc.pdf',
      createdAt: DateTime(2026, 11, 2),
    );

    pages.add('c.jpg');

    expect(doc.pagePaths, <String>['a.jpg', 'b.jpg']);
  });

  test('reordering a document keeps its three lists in step', () {
    final ScanDocument doc = _fromStiffLists();

    doc.applyPageOrder(<int>[1, 0]);

    expect(doc.pagePaths, <String>['b.jpg', 'a.jpg']);
    expect(doc.originalPaths, <String>['b.jpg', 'a.jpg']);
    expect(doc.pagePresets.length, 2);
    expect(doc.pageCrops.length, 2);
  });

  test('crops default to the full frame when none are supplied', () {
    final ScanDocument doc = ScanDocument(
      id: 'doc',
      title: 'Doc',
      pagePaths: <String>['a.jpg'],
      originalPaths: <String>['a.jpg'],
      pagePresets: <ScanPreset>[ScanPreset.auto],
      pdfPath: 'doc.pdf',
      createdAt: DateTime(2026, 11, 2),
    );

    expect(doc.pageCrops.single.tlX, 0);
    expect(doc.pageCrops.single.brX, 1);
  });

  test('save quality survives a round trip and defaults to original', () {
    final ScanDocument doc = ScanDocument(
      id: 'doc',
      title: 'Doc',
      pagePaths: <String>['a.jpg'],
      originalPaths: <String>['a.jpg'],
      pagePresets: <ScanPreset>[ScanPreset.auto],
      pdfPath: 'doc.pdf',
      createdAt: DateTime(2026, 11, 2),
      quality: SaveQuality.small,
    );

    expect(doc.quality.maxEdge, 1080);
    expect(
      ScanDocument.fromJson(doc.toJson()).quality,
      SaveQuality.small,
      reason: 'the editor re-renders at the document\'s own quality',
    );

    // A document written before the setting existed keeps max detail.
    final Map<String, dynamic> legacy = doc.toJson()..remove('quality');
    expect(
      ScanDocument.fromJson(legacy).quality,
      SaveQuality.original,
    );
  });
}
