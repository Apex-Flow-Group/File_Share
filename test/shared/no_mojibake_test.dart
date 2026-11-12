import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic read once as Windows-1256 and saved as UTF-8: the TV receive tab
/// showed «ط§ظ„ظ†ط¸ط§ظ…» for a month. The same for "─" read as cp1252.
void main() {
  test('no source text is double-encoded', () {
    final bad = RegExp(r'ط§ظ„|ظ„ط|â”');
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (bad.hasMatch(lines[i])) {
          found.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(found, isEmpty);
  });
}
