import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_document.dart';
import 'package:scanner_app/models/scan_preset.dart';
import 'package:scanner_app/services/library_search.dart';

ScanDocument _doc(String title, DateTime createdAt) => ScanDocument(
  id: createdAt.microsecondsSinceEpoch.toString(),
  title: title,
  pagePaths: <String>['$title.jpg'],
  originalPaths: <String>['$title.jpg'],
  pagePresets: <ScanPreset>[ScanPreset.auto],
  pdfPath: '$title.pdf',
  createdAt: createdAt,
);

List<String> _titles(List<ScanDocument> docs) =>
    docs.map((ScanDocument d) => d.title).toList();

void main() {
  final List<ScanDocument> library = <ScanDocument>[
    _doc('Kwitansi Sewa Kendaraan Oktober 2026', DateTime(2026, 11, 3)),
    _doc('Uji Mutu', DateTime(2026, 11, 2)),
    _doc('Scan 31 Oct 2026 22.10', DateTime(2026, 11, 1)),
  ];

  test('an empty query keeps the whole library', () {
    expect(searchByName(library, ''), hasLength(3));
    expect(searchByName(library, '   '), hasLength(3));
  });

  test('matching ignores case', () {
    expect(
      _titles(searchByName(library, 'KWITANSI')),
      <String>['Kwitansi Sewa Kendaraan Oktober 2026'],
    );
  });

  test('every word of the query must appear in the name', () {
    expect(
      _titles(searchByName(library, 'kwitansi okt')),
      <String>['Kwitansi Sewa Kendaraan Oktober 2026'],
    );
    // Both words exist in the library, but not in the same name.
    expect(searchByName(library, 'kwitansi uji'), isEmpty);
  });

  test('words may be typed in any order', () {
    expect(
      _titles(searchByName(library, 'oktober  kwitansi')),
      <String>['Kwitansi Sewa Kendaraan Oktober 2026'],
    );
  });

  test('a name with no matching word gives no results', () {
    expect(searchByName(library, 'invoice'), isEmpty);
  });

  test('the library order is kept, not re-ranked by match position', () {
    expect(
      _titles(searchByName(library, '2026')),
      <String>['Kwitansi Sewa Kendaraan Oktober 2026', 'Scan 31 Oct 2026 22.10'],
    );
  });

  test('names are matched literally, not as patterns', () {
    expect(nameMatches('Scan (1)', '('), isTrue);
    expect(nameMatches('Scan 1', '.*'), isFalse);
    expect(nameMatches('Scan 1', 'sc.n 1'), isFalse);
  });

  test('a name that is only part of the query does not match', () {
    expect(nameMatches('Kwitansi', 'kwitansi sewa'), isFalse);
    expect(nameMatches('Kwitansi Sewa', 'kwitansi sewa'), isTrue);
  });
}
