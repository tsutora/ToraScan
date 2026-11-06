import 'dart:convert';
import 'dart:io';

import '../models/scan_document.dart';
import '../models/scan_folder.dart';
import 'library_paths.dart';
import 'pdf_builder.dart';
import 'storage_service.dart';

/// Local-only document library, stored in a folder the user can open.
///
/// Layout is described in [LibraryPaths]: one directory per in-app folder,
/// one PDF per scan, and a hidden `.library/` for the index and page images.
///
/// Documents and folders are stored in separate files so a library written
/// before folders existed still loads without migration.
class ScanStore {
  ScanStore();

  LibraryLocation? _location;
  bool _ready = false;
  Future<void>? _preparing;

  static String get _sep => Platform.pathSeparator;

  Future<LibraryLocation> location() async =>
      _location ??= await StorageService.locate();

  /// Forgets the cached location, e.g. after the user grants storage access.
  void resetLocation() {
    _location = null;
    _ready = false;
  }

  Future<Directory> _metaDir() async {
    final LibraryLocation loc = await location();
    final Directory dir = Directory(
      '${loc.root.path}$_sep${LibraryPaths.meta}',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async =>
      File('${(await _metaDir()).path}$_sep${LibraryPaths.index}');

  Future<File> _folderFile() async =>
      File('${(await _metaDir()).path}$_sep${LibraryPaths.folders}');

  /// A scan's working directory inside `.library/`.
  Future<Directory> sessionDir(String id) async {
    final Directory dir = Directory('${(await _metaDir()).path}$_sep$id');
    await dir.create(recursive: true);
    return dir;
  }

  /// The visible directory for a folder, created if missing.
  Future<Directory> folderDir(String? folderName) async {
    final Directory dir = await folderDirPath(folderName);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// The visible directory for a folder, without creating it.
  Future<Directory> folderDirPath(String? folderName) async {
    final LibraryLocation loc = await location();
    return Directory(
      '${loc.root.path}$_sep${LibraryPaths.folderDirName(folderName)}',
    );
  }

  /// Where a scan's PDF belongs, given its folder and title.
  Future<String> pdfPathFor({
    String? folderId,
    required String title,
    String? currentPath,
  }) async {
    String? folderName;
    if (folderId != null) {
      for (final ScanFolder folder in await loadFolders()) {
        if (folder.id == folderId) {
          folderName = folder.name;
          break;
        }
      }
    }
    final Directory dir = await folderDir(folderName);
    return LibraryPaths.uniquePath(
      dir.path,
      '${LibraryPaths.safeName(title)}.pdf',
      ignorePath: currentPath,
    );
  }

  // ------------------------------------------------------------- documents

  Future<List<ScanDocument>> load() async {
    await _ensureReady();
    final File file = await _indexFile();
    if (!await file.exists()) {
      return <ScanDocument>[];
    }
    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return <ScanDocument>[];
      }
      final List<ScanDocument> docs = decoded
          .map((dynamic e) => ScanDocument.fromJson(e as Map<String, dynamic>))
          .toList();
      docs.sort(
        (ScanDocument a, ScanDocument b) => b.createdAt.compareTo(a.createdAt),
      );
      return docs;
    } on FormatException {
      return <ScanDocument>[];
    }
  }

  Future<void> add(ScanDocument doc) async {
    final List<ScanDocument> docs = await load();
    docs.insert(0, doc);
    await _write(docs);
  }

  /// Replaces an existing document (page edits, reorder, new PDF) by id.
  Future<void> update(ScanDocument doc) async {
    final List<ScanDocument> docs = await load();
    final int index = docs.indexWhere((ScanDocument d) => d.id == doc.id);
    if (index == -1) {
      docs.insert(0, doc);
    } else {
      docs[index] = doc;
    }
    await _write(docs);
  }

  /// Renames a scan and moves its PDF to the matching file name.
  Future<void> rename(ScanDocument doc, String title) async {
    doc.title = title;
    await relocate(doc);
    doc.touch();
    await update(doc);
  }

  /// Moves a document into [folderId], or out of every folder when null, and
  /// moves its PDF into the matching directory.
  Future<void> moveToFolder(ScanDocument doc, String? folderId) async {
    doc.folderId = folderId;
    await relocate(doc);
    doc.touch();
    await update(doc);
  }

  /// Moves [doc]'s PDF to where its current title and folder say it belongs.
  ///
  /// Silently keeps the old path if the file cannot be moved, so a rename can
  /// never lose a document.
  Future<void> relocate(ScanDocument doc) async {
    try {
      final String target = await pdfPathFor(
        folderId: doc.folderId,
        title: doc.title,
        currentPath: doc.pdfPath,
      );
      if (target == doc.pdfPath) {
        return;
      }
      final File source = File(doc.pdfPath);
      if (await source.exists()) {
        await source.copy(target);
        await source.delete();
      }
      doc.pdfPath = target;
    } on FileSystemException {
      // Keep the existing path; the PDF is still where it was.
    }
  }

  /// Copies a scan inside the library and returns the copy.
  ///
  /// Nothing is shared with the original: the working pages, the untouched
  /// captures and the PDF are all copied to a new session directory, so
  /// deleting or editing the copy can never reach back into the source. The
  /// presets, crops and save quality come along unchanged, because the copy is
  /// a duplicate of what the user already tuned.
  Future<ScanDocument> duplicate(ScanDocument doc) async {
    final List<ScanDocument> docs = await load();
    final String id = await _freshId();
    final Directory session = await sessionDir(id);
    final Directory originals = Directory(
      '${session.path}$_sep${LibraryPaths.originals}',
    );
    final Directory pages = Directory(
      '${session.path}$_sep${LibraryPaths.pages}',
    );
    await originals.create(recursive: true);
    await pages.create(recursive: true);

    final String title = _copyTitle(doc.title, docs);
    final List<String> pagePaths = <String>[];
    final List<String> originalPaths = <String>[];
    for (int i = 0; i < doc.pagePaths.length; i++) {
      final String name = 'page_${(i + 1).toString().padLeft(2, '0')}.jpg';
      pagePaths.add(
        await _copyInto(doc.pagePaths[i], '${pages.path}$_sep$name'),
      );
      final String original = i < doc.originalPaths.length
          ? doc.originalPaths[i]
          : doc.pagePaths[i];
      originalPaths.add(
        await _copyInto(original, '${originals.path}$_sep$name'),
      );
    }

    final String pdfPath = await pdfPathFor(
      folderId: doc.folderId,
      title: title,
    );
    if (await File(doc.pdfPath).exists()) {
      await File(doc.pdfPath).copy(pdfPath);
    } else if (pagePaths.isNotEmpty) {
      // A document whose PDF went missing still deserves a usable copy.
      await PdfBuilder.build(pagePaths: pagePaths, outputPath: pdfPath);
    }

    final ScanDocument copy = ScanDocument(
      id: id,
      title: title,
      pagePaths: pagePaths,
      originalPaths: originalPaths,
      pagePresets: doc.pagePresets,
      pageCrops: doc.pageCrops,
      pdfPath: pdfPath,
      // A new timestamp also puts the copy at the top of the library.
      createdAt: DateTime.now(),
      folderId: doc.folderId,
      quality: doc.quality,
    );
    docs.insert(0, copy);
    await _write(docs);
    return copy;
  }

  /// A session id no other document is using.
  Future<String> _freshId() async {
    final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final String meta = (await _metaDir()).path;
    String id = stamp;
    int suffix = 1;
    while (await Directory('$meta$_sep$id').exists()) {
      id = '$stamp-$suffix';
      suffix++;
    }
    return id;
  }

  /// `<title> copy`, then `<title> copy 2`, and so on.
  ///
  /// Copying a copy continues the sequence instead of nesting another "copy",
  /// which is what a user would expect from a file manager.
  static final RegExp _copySuffix = RegExp(r'^(.*) copy(?: (\d+))?$');

  static String _copyTitle(String title, List<ScanDocument> docs) {
    final Set<String> taken = <String>{
      for (final ScanDocument doc in docs) doc.title,
    };

    String base = title;
    int next = 1;
    final RegExpMatch? match = _copySuffix.firstMatch(title);
    if (match != null) {
      base = match.group(1)!;
      next = match.group(2) == null ? 2 : int.parse(match.group(2)!) + 1;
    }

    String candidate = next == 1 ? '$base copy' : '$base copy $next';
    while (taken.contains(candidate)) {
      next++;
      candidate = '$base copy $next';
    }
    return candidate;
  }

  Future<void> remove(ScanDocument doc) async {
    final List<ScanDocument> docs = await load();
    docs.removeWhere((ScanDocument d) => d.id == doc.id);
    await _write(docs);

    for (final String path in <String>[doc.pdfPath, ...doc.pagePaths]) {
      await _deleteQuietly(path);
    }
    final Directory dir = Directory('${(await _metaDir()).path}$_sep${doc.id}');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // --------------------------------------------------------------- folders

  Future<List<ScanFolder>> loadFolders() async {
    await _ensureReady();
    final File file = await _folderFile();
    if (!await file.exists()) {
      return <ScanFolder>[];
    }
    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return <ScanFolder>[];
      }
      return decoded
          .map((dynamic e) => ScanFolder.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return <ScanFolder>[];
    }
  }

  Future<void> addFolder(ScanFolder folder) async {
    final List<ScanFolder> folders = await loadFolders();
    folders.add(folder);
    await _writeFolders(folders);
    await folderDir(folder.name);
  }

  /// Saves a new folder order.
  ///
  /// The order is the whole of `folders.json`, so rewriting it is enough — no
  /// directory moves, no scan is touched. Ids are what documents point at, so
  /// reordering can never orphan a scan.
  Future<void> reorderFolders(List<ScanFolder> ordered) async {
    await _writeFolders(ordered);
  }

  /// Renames a folder, renames its directory, and moves the PDFs inside.
  Future<void> renameFolder(ScanFolder folder, String name) async {
    final String oldName = folder.name;
    final List<ScanFolder> folders = await loadFolders();
    final int index = folders.indexWhere((ScanFolder f) => f.id == folder.id);
    if (index == -1) {
      folder.name = name;
      folders.add(folder);
    } else {
      folders[index].name = name;
      folder.name = name;
    }

    final Directory before = await folderDirPath(oldName);
    final Directory after = await folderDir(name);

    final List<ScanDocument> docs = await load();
    bool changed = false;
    for (final ScanDocument doc in docs) {
      if (doc.folderId != folder.id) {
        continue;
      }
      final String target = LibraryPaths.uniquePath(
        after.path,
        '${LibraryPaths.safeName(doc.title)}.pdf',
        ignorePath: doc.pdfPath,
      );
      final File source = File(doc.pdfPath);
      if (await source.exists()) {
        await source.copy(target);
        await source.delete();
      }
      doc.pdfPath = target;
      changed = true;
    }

    await _writeFolders(folders);
    if (changed) {
      await _write(docs);
    }

    // Only remove the old directory once its PDFs are gone.
    if (before.path != after.path && await before.exists()) {
      try {
        await before.delete();
      } on FileSystemException {
        // Not empty for some other reason; leaving it is harmless.
      }
    }
  }

  /// Deletes a folder but never its contents: the scans inside move to the
  /// unfiled directory, which is the safe default for a destructive action.
  Future<void> removeFolder(ScanFolder folder) async {
    final List<ScanFolder> folders = await loadFolders();
    folders.removeWhere((ScanFolder f) => f.id == folder.id);
    await _writeFolders(folders);

    final List<ScanDocument> docs = await load();
    bool changed = false;
    for (final ScanDocument doc in docs) {
      if (doc.folderId == folder.id) {
        doc.folderId = null;
        await relocate(doc);
        changed = true;
      }
    }
    if (changed) {
      await _write(docs);
    }

    final Directory dir = await folderDirPath(folder.name);
    if (await dir.exists()) {
      try {
        await dir.delete();
      } on FileSystemException {
        // Anything still inside stays; it is the user's file, not ours.
      }
    }
  }

  // --------------------------------------------------------------- writing

  Future<void> _write(List<ScanDocument> docs) async {
    final File file = await _indexFile();
    await file.writeAsString(
      jsonEncode(docs.map((ScanDocument d) => d.toJson()).toList()),
      flush: true,
    );
  }

  Future<void> _writeFolders(List<ScanFolder> folders) async {
    final File file = await _folderFile();
    await file.writeAsString(
      jsonEncode(folders.map((ScanFolder f) => f.toJson()).toList()),
      flush: true,
    );
  }

  static Future<void> _deleteQuietly(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ------------------------------------------------------------- migration

  /// Makes sure `.library/` exists, adopting the library an earlier build left
  /// in the app-private directory the first time it runs.
  ///
  /// Single-flight: two screens opening at once must not both decide the
  /// library is empty and adopt it twice.
  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }
    final Future<void>? pending = _preparing;
    if (pending != null) {
      return pending;
    }
    final Future<void> run = _prepare();
    _preparing = run;
    try {
      await run;
    } finally {
      _preparing = null;
    }
  }

  Future<void> _prepare() async {
    final Directory meta = await _metaDir();
    final File index = File('${meta.path}$_sep${LibraryPaths.index}');
    if (!await index.exists()) {
      await _adoptLegacyLibrary(meta);
    }
    _ready = true;
  }

  /// Copies a library an earlier run left in private storage into the new tree
  /// and rewrites its paths. The old directory is left untouched as a backup.
  ///
  /// Two shapes are understood: the original `scans/` root, whose index sits at
  /// the top, and a `ToraScan/` root this build wrote while the user was still
  /// on private storage, whose index sits in `.library/`.
  Future<void> _adoptLegacyLibrary(Directory meta) async {
    final List<ScanDocument> docs = <ScanDocument>[];
    final List<ScanFolder> folders = <ScanFolder>[];

    final Directory? legacy = await _findLegacyMeta();
    if (legacy != null) {
      final File legacyIndex = File('${legacy.path}$_sep${LibraryPaths.index}');
      if (await legacyIndex.exists()) {
        try {
          final dynamic decoded = jsonDecode(await legacyIndex.readAsString());
          if (decoded is List) {
            docs.addAll(
              decoded.map(
                (dynamic e) => ScanDocument.fromJson(e as Map<String, dynamic>),
              ),
            );
          }
        } on FormatException {
          // A corrupt legacy index is treated as an empty library.
        }
      }
      final File legacyFolders = File(
        '${legacy.path}$_sep${LibraryPaths.folders}',
      );
      if (await legacyFolders.exists()) {
        try {
          final dynamic decoded = jsonDecode(
            await legacyFolders.readAsString(),
          );
          if (decoded is List) {
            folders.addAll(
              decoded.map(
                (dynamic e) => ScanFolder.fromJson(e as Map<String, dynamic>),
              ),
            );
          }
        } on FormatException {
          // Same.
        }
      }
    }

    // Write the index before copying anything. If the process dies mid-copy,
    // the next launch then finds a complete library pointing at the old files
    // instead of a partial one missing the scans that had not been copied yet.
    await _write(docs);
    await _writeFolders(folders);

    for (final ScanDocument doc in docs) {
      final Directory session = Directory('${meta.path}$_sep${doc.id}');
      final Directory originals = Directory(
        '${session.path}$_sep${LibraryPaths.originals}',
      );
      final Directory pages = Directory(
        '${session.path}$_sep${LibraryPaths.pages}',
      );
      await originals.create(recursive: true);
      await pages.create(recursive: true);

      for (int i = 0; i < doc.pagePaths.length; i++) {
        final String name = 'page_${(i + 1).toString().padLeft(2, '0')}.jpg';
        doc.originalPaths[i] = await _copyInto(
          doc.originalPaths[i],
          '${originals.path}$_sep$name',
        );
        doc.pagePaths[i] = await _copyInto(
          doc.pagePaths[i],
          '${pages.path}$_sep$name',
        );
      }

      String? folderName;
      for (final ScanFolder folder in folders) {
        if (folder.id == doc.folderId) {
          folderName = folder.name;
          break;
        }
      }
      final Directory target = await folderDir(folderName);
      doc.pdfPath = await _copyInto(
        doc.pdfPath,
        LibraryPaths.uniquePath(
          target.path,
          '${LibraryPaths.safeName(doc.title)}.pdf',
        ),
      );
    }

    // Create the directory for every folder, even an empty one.
    for (final ScanFolder folder in folders) {
      await folderDir(folder.name);
    }

    await _write(docs);
    await _writeFolders(folders);
  }

  /// The meta directory of the first earlier library that actually has an
  /// index, preferring the newest layout.
  static Future<Directory?> _findLegacyMeta() async {
    for (final Directory root in await StorageService.legacyRoots()) {
      for (final Directory candidate in <Directory>[
        Directory('${root.path}$_sep${LibraryPaths.meta}'),
        root,
      ]) {
        final File index = File('${candidate.path}$_sep${LibraryPaths.index}');
        if (await index.exists()) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Copies [source] to [target], returning whichever path now holds the file.
  static Future<String> _copyInto(String source, String target) async {
    final File file = File(source);
    if (!await file.exists()) {
      return target;
    }
    await file.copy(target);
    return target;
  }
}
