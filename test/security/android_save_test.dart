import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android saves received files in Kotlin, which flutter test cannot run, so
/// these read the code. What each one prevents:
/// - Android 9 and older wrote straight to Downloads/ApexShare/<name>,
///   replacing a file the user already had, and an interrupted copy left a
///   cut file under its real name.
/// - Android 10+ MediaStore renames on a clash ("report (1).txt"), but the
///   path returned was built from the asked name, so "open" showed the older
///   file; and a failed copy left a pending (hidden, cut) entry behind.
void main() {
  final code = File('android/app/src/main/kotlin/com/apexflow/tools/transfer/FileOperationsHandler.kt')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');
  final save = RegExp(r'private fun saveToDownloads\([\s\S]*?\n    \}\n').firstMatch(code)?.group(0);

  test('the save code is found', () {
    expect(save, isNotNull, reason: 'saveToDownloads moved; update this test.');
  });

  test('Android 9 and older never write to the final name, and never replace a file', () {
    final old = save!.substring(save.indexOf('Android 9 and below'));
    expect(old, isNot(contains(RegExp(r'(?<!free)File\(destDir, fileName\)'))),
        reason: 'The received bytes go straight to the final name.');
    expect(old, contains('.part'));
    expect(old, contains('freeFile(destDir, fileName)'));
    expect(old, contains('renameTo'));
  });

  test('the free name follows the app rule: _1, _2, within 255 bytes', () {
    expect(code, contains(r'"_$n$ext"'));
    expect(code, contains('255 -'));
  });

  test('Android 10+ returns the name MediaStore kept, and leaves no pending entry on failure', () {
    final q = save!.substring(0, save.indexOf('Android 9 and below'));
    expect(q, contains('arrayOf(MediaStore.Downloads.DISPLAY_NAME)'));
    expect(q, isNot(contains(r'/$fileName"')), reason: 'The path is built from the asked name.');
    expect(q, contains('resolver.delete(uri'));
  });
}
