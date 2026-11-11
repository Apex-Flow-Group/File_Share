import 'dart:io';

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/shared/folder_open_message.dart';
import 'package:apex_file_share/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('a deleted or moved folder says so', () {
    expect(folderOpenMessage(const FolderOpenError(missing: true), ar), 'المجلد محذوف أو منقول.');
  });

  test('no app to open folders says the folder could not be opened', () {
    expect(folderOpenMessage(const FolderOpenError(), ar), 'تعذّر فتح المجلد.');
  });

  test('the shared folder deleted from disk says so, and opens no other place', () async {
    final gone = '${Directory.systemTemp.path}/apex_never_created_${DateTime.now().microsecondsSinceEpoch}';
    await expectLater(FileUtils.openFolder(gone),
        throwsA(isA<FolderOpenError>().having((e) => e.missing, 'missing', isTrue)));
  });

  test('a library error never reaches the user', () {
    final shown = folderOpenMessage(Exception('No APP found to open this file.'), ar);
    expect(shown, 'تعذّر فتح المجلد.');
    expect(shown, isNot(contains('Exception')));
  });
}
