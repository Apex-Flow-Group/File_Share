@TestOn('windows || linux')
library;

import 'dart:io';

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/platform/open_with_app.dart';
import 'package:apex_file_share/shared/file_open_message.dart';
import 'package:apex_file_share/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows: success, missing file and no app are told apart', () {
    expect(windowsOpenResult(42), DesktopOpen.opened);
    expect(windowsOpenResult(2), DesktopOpen.missing);
    expect(windowsOpenResult(3), DesktopOpen.missing);
    expect(windowsOpenResult(31), DesktopOpen.noApp);
    expect(windowsOpenResult(27), DesktopOpen.noApp);
    expect(windowsOpenResult(5), DesktopOpen.failed, reason: 'access denied');
    expect(windowsOpenResult(0), DesktopOpen.failed, reason: 'out of memory');
  });

  test('Linux: xdg-open exit codes are read, not ignored', () {
    expect(linuxOpenResult(0), DesktopOpen.opened);
    expect(linuxOpenResult(2), DesktopOpen.missing);
    expect(linuxOpenResult(3), DesktopOpen.noApp);
    expect(linuxOpenResult(4), DesktopOpen.failed);
  });

  test('a file that is not there is reported, and nothing is launched', () async {
    final dir = await Directory.systemTemp.createTemp('apex_open_');
    try {
      expect(await openOnDesktop('${dir.path}/gone.pdf'), DesktopOpen.missing);
      await expectLater(FileUtils.openFile('${dir.path}/gone.pdf'),
          throwsA(isA<FileOpenError>().having((e) => e.result, 'result', DesktopOpen.missing)));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('the real ShellExecuteW is reached and answers "not found" for a missing file', () async {
    final dir = await Directory.systemTemp.createTemp('apex_open_');
    try {
      final code = await shellExecuteCode('${dir.path}${Platform.pathSeparator}gone.pdf');
      expect(windowsOpenResult(code), DesktopOpen.missing, reason: 'code $code');
    } finally {
      await dir.delete(recursive: true);
    }
  }, testOn: 'windows');

  test('the user reads why, never the error itself', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(fileOpenMessage(const FileOpenError(DesktopOpen.missing), l10n), l10n.fileMissing);
    expect(fileOpenMessage(const FileOpenError(DesktopOpen.noApp), l10n), l10n.noAppForFile);
    expect(fileOpenMessage(const FileOpenError(DesktopOpen.failed), l10n), l10n.openFileFailed);
    expect(fileOpenMessage(Exception('PlatformException(x)'), l10n), l10n.openFileFailed);
  });
}
