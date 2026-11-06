import '../models/scan_document.dart';

/// Name search for the library.
///
/// Only the name a scan was saved under is searched: ToraScan never reads the
/// page itself, so a search returns instantly on a large library and works
/// offline like everything else in the app.
///
/// Matching ignores case and runs of spaces, and every word of the query has to
/// appear somewhere in the name. That means `kwitansi okt` finds
/// `Kwitansi Sewa Kendaraan Oktober 2026` without the user retyping the parts
/// of the title they cannot remember.
String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Whether [title] answers [query]. An empty query answers everything.
bool nameMatches(String title, String query) {
  final String q = _normalize(query);
  if (q.isEmpty) {
    return true;
  }
  final String name = _normalize(title);
  for (final String word in q.split(' ')) {
    if (!name.contains(word)) {
      return false;
    }
  }
  return true;
}

/// The documents whose names match [query], in the order they were given.
///
/// The order is kept rather than re-ranked by where the match falls: the list
/// underneath a search is still the library the user knows, just shorter.
List<ScanDocument> searchByName(List<ScanDocument> documents, String query) {
  if (_normalize(query).isEmpty) {
    return List<ScanDocument>.of(documents);
  }
  return documents
      .where((ScanDocument doc) => nameMatches(doc.title, query))
      .toList();
}
