@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';

void main() {
  test('Android 12+ device-to-device transfer and cloud backup copy nothing', () {
    // With targetSdk 31+, allowBackup="false" no longer stops device-to-device
    // transfer; only dataExtractionRules does.
    final manifest = File(_manifest).readAsStringSync();
    final ref = RegExp(r'android:dataExtractionRules="@xml/([a-z_]+)"').firstMatch(manifest);
    expect(ref, isNotNull, reason: '$_manifest has no dataExtractionRules');
    final rules = File('android/app/src/main/res/xml/${ref!.group(1)}.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section[^>]*>([\\s\\S]*?)</$section>').firstMatch(rules)?.group(1) ?? '';
      for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(RegExp('<exclude domain="$domain" path="\\."').hasMatch(body), isTrue,
            reason: '$section does not exclude $domain');
      }
    }
  });

  test('nothing is shared through a FileProvider outside the save folders', () {
    final paths = File('android/app/src/main/res/xml/file_paths.xml').readAsStringSync();
    final open = RegExp(r'<[a-z-]+-path[^>]*path="(\.?/?)"').allMatches(paths).map((m) => m.group(0));
    expect(open, isEmpty, reason: 'path="." shares a whole storage area.');
  });
}
