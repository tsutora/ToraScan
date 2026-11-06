import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Where the library lives.
enum StorageMode {
  /// A real folder on shared internal storage, visible to file managers,
  /// the system Files app, and a USB connection.
  shared,

  /// The app's private documents directory, used only when the user declines
  /// all-files access. Everything still works; the files are just not visible.
  private,
}

class LibraryLocation {
  const LibraryLocation({required this.root, required this.mode});

  final Directory root;
  final StorageMode mode;

  bool get isShared => mode == StorageMode.shared;
}

/// Resolves the library root and talks to the Android side for the one
/// permission this needs.
///
/// Writing a folder at `/storage/emulated/0/ToraScan` (rather than the
/// app-private directory) is what makes the library browsable outside the app.
/// On Android 11+ that requires `MANAGE_EXTERNAL_STORAGE`, which the user
/// grants once in Settings.
class StorageService {
  const StorageService._();

  static const MethodChannel _channel = MethodChannel('torascan/storage');

  /// The visible folder name on shared storage.
  static const String folderName = 'ToraScan';

  static String get _sep => Platform.pathSeparator;

  static Future<bool> hasSharedAccess() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the "All files access" screen for this app.
  static Future<void> openAccessSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openAllFilesSettings');
    } on PlatformException {
      // Nothing useful to do; the gate offers a retry.
    } on MissingPluginException {
      // Same.
    }
  }

  static Future<String?> externalRootPath() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('externalRoot');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The current library root, created if missing.
  static Future<LibraryLocation> locate() async {
    final String? external = await externalRootPath();
    if (external != null && await hasSharedAccess()) {
      final Directory root = Directory('$external$_sep$folderName');
      await root.create(recursive: true);
      return LibraryLocation(root: root, mode: StorageMode.shared);
    }

    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory root = Directory('${docs.path}$_sep$folderName');
    await root.create(recursive: true);
    return LibraryLocation(root: root, mode: StorageMode.private);
  }

  /// Directories an earlier run may have left a library in, newest layout first.
  ///
  /// `scans/` is what the first build wrote; `ToraScan/` is what this build
  /// writes when the user is still on private storage. Both are adopted when
  /// the library moves somewhere new, so granting access later never strands
  /// scans behind.
  static Future<List<Directory>> legacyRoots() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final List<Directory> roots = <Directory>[];
    for (final String name in <String>['scans', folderName]) {
      final Directory dir = Directory('${docs.path}$_sep$name');
      if (await dir.exists()) {
        roots.add(dir);
      }
    }
    return roots;
  }
}
