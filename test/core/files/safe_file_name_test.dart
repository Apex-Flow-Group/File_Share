import 'dart:convert';

import 'package:apex_file_share/core/files/safe_file_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixed = DateTime(2026, 10, 23, 9, 5, 7);
  String clean(String? raw) => safeFileName(raw, now: () => fixed);

  test('a normal name is kept as is', () {
    expect(clean('report.pdf'), 'report.pdf');
    expect(clean('تقرير الشهر.xlsx'), 'تقرير الشهر.xlsx');
  });

  test('characters Windows forbids become "_"', () {
    expect(clean('notes: draft?.txt'), 'notes_ draft_.txt');
    expect(clean('a<b>c"d|e*f.txt'), 'a_b_c_d_e_f.txt');
  });

  test('a name cannot climb out of the folder', () {
    for (final raw in ['../../escape.txt', r'..\..\escape.txt', '/etc/passwd', r'C:\x.txt']) {
      final name = clean(raw);
      expect(name.contains('/') || name.contains(r'\') || name.startsWith('.'), isFalse,
          reason: '$raw became $name');
    }
  });

  test('control characters are removed from the name', () {
    final raw = String.fromCharCodes([...'a'.codeUnits, 0, 7, 31, ...'b.txt'.codeUnits]);
    expect(clean(raw), 'a___b.txt');
  });

  test('direction marks cannot disguise the real extension', () {
    // "photo<RLO>gpj.exe" is shown as "photoexe.jpg" but runs as .exe.
    final raw = String.fromCharCodes([...'photo'.codeUnits, 0x202E, ...'gpj.exe'.codeUnits]);
    expect(clean(raw), 'photogpj.exe');
  });

  test('Windows reserved device names get a prefix', () {
    expect(clean('CON'), '_CON');
    expect(clean('nul.txt'), '_nul.txt');
    expect(clean('com1.log'), '_com1.log');
    expect(clean('console.txt'), 'console.txt');
  });

  test('trailing dots and spaces are removed (Windows drops them silently)', () {
    expect(clean('name.txt. . '), 'name.txt');
  });

  test('an empty or missing name gets a time-based name', () {
    expect(clean(null), 'file_20261023_090507');
    expect(clean(''), 'file_20261023_090507');
    expect(clean(' .. '), 'file_20261023_090507');
  });

  test('a long name is cut to 255 bytes and keeps its extension', () {
    final name = clean('${'ع' * 300}.pdf');
    expect(utf8.encode(name).length, lessThanOrEqualTo(255));
    expect(name.endsWith('.pdf'), isTrue);
  });
}
