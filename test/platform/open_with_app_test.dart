@TestOn('windows || linux')
library;

import 'dart:io';

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/platform/open_with_app.dart';
import 'package:apex_file_share/shared/file_open_message.dart';
import 'package:apex_file_share/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart' show ResultType;

void main() {
  test('Windows: success, missing file and no app are told apart', () {
    expect(windowsOpenResult(42), FileOpenResult.opened);
    expect(windowsOpenResult(2), FileOpenResult.missing);
    expect(windowsOpenResult(3), FileOpenResult.missing);
    expect(windowsOpenResult(31), FileOpenResult.noApp);
    expect(windowsOpenResult(27), FileOpenResult.noApp);
    expect(windowsOpenResult(5), FileOpenResult.failed, reason: 'access denied');
    expect(windowsOpenResult(0), FileOpenResult.failed, reason: 'out of memory');
  });

  test('Linux: xdg-open exit codes are read, not ignored', () {
    expect(linuxOpenResult(0), FileOpenResult.opened);
    expect(linuxOpenResult(2), FileOpenResult.missing);
    expect(linuxOpenResult(3), FileOpenResult.noApp);
    expect(linuxOpenResult(4), FileOpenResult.failed);
  });

  test('Android: the reason from the native side reaches the user', () {
    expect(androidOpenResult('FILE_NOT_FOUND'), FileOpenResult.missing);
    expect(androidOpenResult('NO_APP'), FileOpenResult.noApp);
    expect(androidOpenResult('OPEN_FAILED'), FileOpenResult.failed);
  });

  test('open_filex: "no app" is no longer taken as success', () {
    expect(openFilexResult(ResultType.done), FileOpenResult.opened);
    expect(openFilexResult(ResultType.noAppToOpen), FileOpenResult.noApp);
    expect(openFilexResult(ResultType.fileNotFound), FileOpenResult.missing);
    expect(openFilexResult(ResultType.permissionDenied), FileOpenResult.failed);
    expect(openFilexResult(ResultType.error), FileOpenResult.failed);
  });

  test('every code the Android side sends is one Dart knows', () {
    final kt = File('android/app/src/main/kotlin/com/apexflow/tools/transfer/FileOperationsHandler.kt')
        .readAsStringSync();
    final body = kt.substring(kt.indexOf('private fun openFile('), kt.indexOf('private fun openFileLocation('));
    final codes = RegExp(r'result\.error\("([A-Z_]+)"').allMatches(body).map((m) => m.group(1)).toSet();
    expect(codes, {'FILE_NOT_FOUND', 'NO_APP', 'OPEN_FAILED'});
  });

  test('a file that is not there is reported, and nothing is launched', () async {
    final dir = await Directory.systemTemp.createTemp('apex_open_');
    try {
      expect(await openOnDesktop('${dir.path}/gone.pdf'), FileOpenResult.missing);
      await expectLater(FileUtils.openFile('${dir.path}/gone.pdf'),
          throwsA(isA<FileOpenError>().having((e) => e.result, 'result', FileOpenResult.missing)));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('the real ShellExecuteW is reached and answers "not found" for a missing file', () async {
    final dir = await Directory.systemTemp.createTemp('apex_open_');
    try {
      final code = await shellExecuteCode('${dir.path}${Platform.pathSeparator}gone.pdf');
      expect(windowsOpenResult(code), FileOpenResult.missing, reason: 'code $code');
    } finally {
      await dir.delete(recursive: true);
    }
  }, testOn: 'windows');

  test('the user reads why, never the error itself', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(fileOpenMessage(const FileOpenError(FileOpenResult.missing), l10n), l10n.fileMissing);
    expect(fileOpenMessage(const FileOpenError(FileOpenResult.noApp), l10n), l10n.noAppForFile);
    expect(fileOpenMessage(const FileOpenError(FileOpenResult.failed), l10n), l10n.openFileFailed);
    expect(fileOpenMessage(Exception('PlatformException(x)'), l10n), l10n.openFileFailed);
  });
}
