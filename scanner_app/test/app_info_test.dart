import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/app_info.dart';

void main() {
  test('the shown version matches pubspec', () {
    // A stale label is worse than no label: it would tell a user they are on a
    // build they are not.
    final List<String> lines = File('pubspec.yaml').readAsLinesSync();
    final String version = lines
        .firstWhere((String line) => line.startsWith('version:'))
        .split(':')[1]
        .trim();
    final String name = version.split('+').first;

    expect(
      toraVersion,
      name,
      reason: 'lib/app_info.dart says $toraVersion, pubspec says $name',
    );
  });
}
