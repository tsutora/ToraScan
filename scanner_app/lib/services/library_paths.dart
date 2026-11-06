import 'dart:io';

/// The on-disk layout of the library.
///
/// ```
/// ToraScan/
///   Uji mutu/                     one directory per in-app folder
///     Ajakak.pdf                  one PDF per scan, named after it
///   Unsorted/                     scans that are not in a folder
///     Scan 28 Oct 2026 15.04.pdf
///   .library/                     internal working data, hidden from the
///     index.json                  file browser
///     folders.json
///     1793170674361116/
///       pages/page_01.jpg
///       orig/page_01.jpg
/// ```
///
/// Keeping the pages inside `.library` means the visible tree stays clean —
/// one folder, one PDF — while re-cropping and preset changes still have the
/// untouched capture to work from.
class LibraryPaths {
  const LibraryPaths._();

  static const String unfiled = 'Unsorted';
  static const String meta = '.library';
  static const String pages = 'pages';
  static const String originals = 'orig';
  static const String index = 'index.json';
  static const String folders = 'folders.json';

  static String get _sep => Platform.pathSeparator;

  /// Characters that are illegal in a file name on Android, Windows and macOS.
  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

  /// A name that is safe to use as a file or directory on every platform.
  static String safeName(String raw, {String fallback = 'Untitled'}) {
    String cleaned = raw
        .replaceAll(_illegal, '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    // Trailing dots and spaces are legal on Android but break when the folder
    // is copied to Windows over USB, so they are stripped here.
    cleaned = cleaned.replaceAll(RegExp(r'[. ]+$'), '').trim();
    if (cleaned.length > 80) {
      cleaned = cleaned.substring(0, 80).trim();
    }
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// The directory name for a folder, or the unfiled bucket when null.
  static String folderDirName(String? folderName) {
    if (folderName == null || folderName.trim().isEmpty) {
      return unfiled;
    }
    final String name = safeName(folderName, fallback: unfiled);
    // A user folder may not take the unfiled bucket's name.
    if (name.toLowerCase() == unfiled.toLowerCase()) {
      return '$name (2)';
    }
    return name;
  }

  /// A path inside [directory] that does not collide with an existing file.
  ///
  /// [ignorePath] is the file being renamed or moved, so it does not count as
  /// a collision with itself.
  static String uniquePath(
    String directory,
    String fileName, {
    String? ignorePath,
  }) {
    String stem = fileName;
    String extension = '';
    final int dot = fileName.lastIndexOf('.');
    if (dot > 0) {
      stem = fileName.substring(0, dot);
      extension = fileName.substring(dot);
    }

    String candidate = '$directory$_sep$stem$extension';
    int counter = 2;
    while (File(candidate).existsSync() && candidate != ignorePath) {
      candidate = '$directory$_sep$stem ($counter)$extension';
      counter++;
    }
    return candidate;
  }

  static String join(String a, String b) => '$a$_sep$b';
}
