import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/services/library_paths.dart';

/// The library is a real tree of directories and PDFs on shared storage, so the
/// naming rules are what stop a document title like `Invoice 3/2026` from
/// creating a stray directory or overwriting an unrelated scan.
void main() {
  group('safeName', () {
    test('replaces every character that is illegal in a path', () {
      expect(
        LibraryPaths.safeName(r'Invoice 3/2026 <draft>'),
        'Invoice 3_2026 _draft_',
      );
    });

    test('collapses whitespace and trims', () {
      expect(LibraryPaths.safeName('  Ajakak    scan  '), 'Ajakak scan');
    });

    test(
      'drops trailing dots and spaces so a USB copy to Windows survives',
      () {
        expect(LibraryPaths.safeName('Report v2.  '), 'Report v2');
      },
    );

    test('falls back when nothing usable is left', () {
      expect(LibraryPaths.safeName('   '), 'Untitled');
      expect(LibraryPaths.safeName('...', fallback: 'Scan'), 'Scan');
    });

    test('caps very long names', () {
      final String name = LibraryPaths.safeName('a' * 200);
      expect(name.length, 80);
    });
  });

  group('folderDirName', () {
    test('unfiled scans go to a visible bucket', () {
      expect(LibraryPaths.folderDirName(null), 'Unsorted');
      expect(LibraryPaths.folderDirName('   '), 'Unsorted');
    });

    test('a user folder keeps its name', () {
      expect(LibraryPaths.folderDirName('Uji mutu'), 'Uji mutu');
    });

    test('a user folder may not collide with the unfiled bucket', () {
      expect(LibraryPaths.folderDirName('Unsorted'), 'Unsorted (2)');
      expect(LibraryPaths.folderDirName('unsorted'), 'unsorted (2)');
    });
  });

  group('uniquePath', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tora_paths_');
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns the plain path when nothing is there', () {
      expect(
        LibraryPaths.uniquePath(dir.path, 'Ajakak.pdf'),
        '${dir.path}${Platform.pathSeparator}Ajakak.pdf',
      );
    });

    test('numbers the second copy instead of overwriting the first', () {
      File('${dir.path}${Platform.pathSeparator}Ajakak.pdf')
          .writeAsStringSync('');
      expect(
        LibraryPaths.uniquePath(dir.path, 'Ajakak.pdf'),
        '${dir.path}${Platform.pathSeparator}Ajakak (2).pdf',
      );
    });

    test('keeps counting past the second copy', () {
      for (final String name in <String>['Ajakak.pdf', 'Ajakak (2).pdf']) {
        File('${dir.path}${Platform.pathSeparator}$name').writeAsStringSync('');
      }
      expect(
        LibraryPaths.uniquePath(dir.path, 'Ajakak.pdf'),
        '${dir.path}${Platform.pathSeparator}Ajakak (3).pdf',
      );
    });

    test('does not count the file being renamed as a collision', () {
      final String existing = '${dir.path}${Platform.pathSeparator}Ajakak.pdf';
      File(existing).writeAsStringSync('');
      expect(
        LibraryPaths.uniquePath(dir.path, 'Ajakak.pdf', ignorePath: existing),
        existing,
      );
    });
  });
}
