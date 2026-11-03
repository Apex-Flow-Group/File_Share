@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // A JSON reader keeps the last of two equal keys without a word, so the
  // text on screen silently differs from the one that was reviewed.
  test('no key appears twice in a translation file', () {
    final hits = <String>[];
    for (final f in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!f.path.endsWith('.arb')) {
        continue;
      }
      final seen = <String, int>{};
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = RegExp(r'^  "([^"]+)":').firstMatch(lines[i]);
        if (m == null) {
          continue;
        }
        final first = seen[m.group(1)!];
        if (first != null) {
          hits.add('${f.path}: "${m.group(1)}" on lines $first and ${i + 1}');
        }
        seen.putIfAbsent(m.group(1)!, () => i + 1);
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
