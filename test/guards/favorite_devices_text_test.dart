@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // In Arabic Android "تثبيت / إلغاء التثبيت" means install / uninstall, and
  // the TV shows "pin" right next to "send app" and "installed apps".
  // Marking a device is "المفضلة"; the saved setting keys keep their names.
  test('marking a device never uses the install word', () {
    final ar = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync()) as Map<String, dynamic>;
    final hits = [
      for (final key in ['pinDevice', 'unpinDevice', 'pinnedDevices'])
        if ((ar[key] as String).contains('ثبت') || !(ar[key] as String).contains('المفضلة'))
          '$key: ${ar[key]}',
    ];
    expect(hits, isEmpty);
  });
}
