@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A file path is cut with fileNameOf (lib/utils/path_name.dart), never by one
/// slash: on Windows the path has "\" and often "/" too, and cutting at "/"
/// shows the whole path where the file name belongs. A line that cuts
/// something else (a URL, a protocol path) says so with "not a file path".
final _bs = String.fromCharCode(92);

final _cutsAtOneSlash = [
  for (final call in ['split', 'lastIndexOf']) ...[
    "$call('/')",
    '$call("/")',
    "$call('$_bs')",
    '$call("$_bs")',
    "$call('$_bs$_bs')",
    '$call(Platform.pathSeparator)',
  ],
];

void main() {
  test('no file path is cut at one kind of slash', () {
    final hits = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.contains('/l10n/generated/') ||
          path.endsWith('lib/utils/path_name.dart')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_cutsAtOneSlash.any(lines[i].contains) &&
            !lines[i].contains('not a file path')) {
          hits.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty,
        reason:
            'use fileNameOf(path) from lib/utils/path_name.dart:\n${hits.join('\n')}');
  });
}
