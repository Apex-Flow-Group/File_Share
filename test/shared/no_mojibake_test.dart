import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic read once as Windows-1256 and saved as UTF-8: the TV receive tab
/// showed «ط§ظ„ظ†ط¸ط§ظ…» for a month, and «ظ…ظ†» for «من» after the first
/// guard looked only for «ال». Every UTF-8 Arabic letter starts with byte
/// D8 or D9 (ط or ظ in Windows-1256); the byte after it becomes a symbol
/// or a Persian letter that never follows ط or ظ in real Arabic. «» and
/// the Arabic comma, semicolon and question mark are left out: they do.
/// The same for "─" and "—" read as cp1252.
void main() {
  test('no source text is double-encoded', () {
    final bad = RegExp(
        r'[\u0637\u0638][\u0080-\u00AA\u00AC-\u00BA\u00BC-\u00BF\u0152\u0153\u0192\u02C6\u2013-\u203A\u20AC\u2122\u067E\u0679\u0686\u0688\u0691\u0698\u06A9\u06AF\u06BA\u06BE\u200C\u200D]|â”|â€');
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

  // Left by an editor on Windows: invisible, and the other files have none.
  test('no source file starts with a byte-order mark', () {
    final found = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && f.readAsBytesSync().take(3).join(',') == '239,187,191')
          f.path,
    ];
    expect(found, isEmpty);
  });
}
