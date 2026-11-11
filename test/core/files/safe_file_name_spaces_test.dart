@TestOn('vm')
library;

import 'dart:io';

import 'package:apex_file_share/core/files/safe_file_name.dart';
import 'package:flutter_test/flutter_test.dart';

const _kotlin = 'android/app/src/main/kotlin/com/apexflow/tools/transfer/SafeFileName.kt';

Set<int> _set(String text, String pattern) => RegExp(r'0x([0-9A-Fa-f]{4})')
    .allMatches(RegExp(pattern).firstMatch(text)!.group(1)!)
    .map((m) => int.parse(m.group(1)!, radix: 16))
    .toSet();

void main() {
  test('a no-break space in a name becomes a normal space', () {
    final raw = 'WhatsApp${String.fromCharCode(0x00A0)}Business.apk';
    expect(safeFileName(raw), 'WhatsApp Business.apk');
  });

  test('every look-alike space becomes a normal space', () {
    for (final cp in [0x00A0, 0x1680, 0x2000, 0x2005, 0x200A, 0x202F, 0x205F, 0x3000]) {
      final raw = 'a${String.fromCharCode(cp)}b.txt';
      expect(safeFileName(raw), 'a b.txt', reason: cp.toRadixString(16));
    }
  });

  test('look-alike spaces at the ends are trimmed like normal ones', () {
    final nb = String.fromCharCode(0x00A0);
    expect(safeFileName('${nb}note.txt$nb'), 'note.txt');
  });

  test('the Kotlin copy treats the same spaces', () {
    final dart = _set(File('lib/core/files/safe_file_name.dart').readAsStringSync(),
        r'_oddSpaces = <int>\{([\s\S]*?)\};');
    final kt = _set(File(_kotlin).readAsStringSync(), r'oddSpaces = setOf\(([\s\S]*?)\)');
    expect(kt, dart);
  });
}
