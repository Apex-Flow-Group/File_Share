@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _kotlin = 'android/app/src/main/kotlin/com/apexflow/tools/transfer/SafeFileName.kt';

String _read(String path) => File(path).readAsStringSync();

Set<int> _hexes(String text) =>
    RegExp(r'0x([0-9A-Fa-f]{4})').allMatches(text).map((m) => int.parse(m.group(1)!, radix: 16)).toSet();

void main() {
  // Names shared into the app on Android are cleaned in Kotlin before they
  // become a path; everything else in Dart. One rule, two copies: they must match.
  test('the Kotlin copy of safeFileName follows the Dart rule', () {
    expect(File(_kotlin).existsSync(), isTrue);
    final kt = _read(_kotlin);
    final dart = _read('lib/core/files/safe_file_name.dart');
    final marks = _read('lib/core/text/invisible_marks.dart');

    final dartMarks = _hexes(RegExp(r'_marks = <int>\{([\s\S]*?)\};').firstMatch(marks)!.group(1)!);
    final ktMarks = _hexes(RegExp(r'invisibleMarks = setOf\(([\s\S]*?)\)').firstMatch(kt)?.group(1) ?? '');
    expect(ktMarks, dartMarks, reason: 'invisible marks');

    final dartForbidden = RegExp(r"_forbidden = '([^']*)'").firstMatch(dart)!.group(1)!;
    final ktForbidden = RegExp(r'FORBIDDEN = "((?:[^"\\]|\\.)*)"').firstMatch(kt)?.group(1);
    expect(ktForbidden, dartForbidden.replaceAll('"', r'\"'), reason: 'forbidden characters');

    final dartReserved = RegExp(r"_reserved = RegExp\(r'([^']*)'").firstMatch(dart)!.group(1)!;
    final ktReserved = RegExp(r'reserved = Regex\("((?:[^"\\]|\\.)*)"').firstMatch(kt)?.group(1);
    expect(ktReserved?.replaceAll(r'\\', r'\'), dartReserved, reason: 'reserved names');

    final dartMax = RegExp(r'_maxBytes = (\d+)').firstMatch(dart)!.group(1);
    expect(RegExp(r'MAX_BYTES = (\d+)').firstMatch(kt)?.group(1), dartMax, reason: 'byte limit');
  });
}
