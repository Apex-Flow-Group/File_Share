import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:open_filex/open_filex.dart' show ResultType;

import 'reveal_in_folder.dart';

enum FileOpenResult { opened, missing, noApp, failed }

/// Opens [path] with the app the system chose for its type, on Windows and
/// Linux; null on other systems, which open files their own way (Android
/// through FileOperationsHandler.kt, answered by [androidOpenResult]).
/// explorer.exe could not be used: its exit code is 1 whatever happened, so a
/// failure showed nothing.
Future<FileOpenResult?> openOnDesktop(String path) async {
  if (!Platform.isWindows && !Platform.isLinux) {
    return null;
  }
  // Checked here: a missing file does not reach either system's own answer,
  // which for a desktop environment without xdg-open's codes is only "failed".
  if (!await File(path).exists()) {
    return FileOpenResult.missing;
  }
  if (Platform.isWindows) {
    final native = windowsPath(path);
    // Off the UI thread: the call waits while Windows finds the app.
    return windowsOpenResult(await shellExecuteCode(native));
  }
  if (Platform.isLinux) {
    return linuxOpenResult((await Process.run('xdg-open', [path])).exitCode);
  }
  return null;
}

/// ShellExecuteW's raw answer for [path], already in Windows form.
@visibleForTesting
Future<int> shellExecuteCode(String path) => Isolate.run(() => _shellExecute(path));

/// ShellExecuteW answers above 32 on success; 2 and 3: file or path not found;
/// 27 and 31: no app for this type.
FileOpenResult windowsOpenResult(int code) => switch (code) {
      > 32 => FileOpenResult.opened,
      2 || 3 => FileOpenResult.missing,
      27 || 31 => FileOpenResult.noApp,
      _ => FileOpenResult.failed,
    };

/// The Android side's error codes (FileOperationsHandler.kt, openFile).
FileOpenResult androidOpenResult(String code) => switch (code) {
      'FILE_NOT_FOUND' => FileOpenResult.missing,
      'NO_APP' => FileOpenResult.noApp,
      _ => FileOpenResult.failed,
    };

/// open_filex's answer; "no app" used to pass as success, so nothing showed.
FileOpenResult openFilexResult(ResultType type) => switch (type) {
      ResultType.done => FileOpenResult.opened,
      ResultType.fileNotFound => FileOpenResult.missing,
      ResultType.noAppToOpen => FileOpenResult.noApp,
      _ => FileOpenResult.failed,
    };

/// xdg-open exit codes: 2, a file does not exist; 3, no tool to open it.
FileOpenResult linuxOpenResult(int code) => switch (code) {
      0 => FileOpenResult.opened,
      2 => FileOpenResult.missing,
      3 => FileOpenResult.noApp,
      _ => FileOpenResult.failed,
    };

typedef _ShellExecuteC = IntPtr Function(IntPtr hwnd, Pointer<Utf16> verb, Pointer<Utf16> file,
    Pointer<Utf16> params, Pointer<Utf16> dir, Int32 show);
typedef _ShellExecuteDart = int Function(
    int hwnd, Pointer<Utf16> verb, Pointer<Utf16> file, Pointer<Utf16> params, Pointer<Utf16> dir, int show);
typedef _CoInitC = Int32 Function(Pointer<Void> reserved, Uint32 flags);
typedef _CoInitDart = int Function(Pointer<Void> reserved, int flags);

/// The default verb, as a double-click in Explorer: a type with no app gets
/// Windows' "open with" choice instead of an error. Nothing is run through a
/// shell, so "&" in a name stays part of the name.
int _shellExecute(String path) {
  const coinitApartmentThreaded = 0x2;
  const coinitDisableOle1Dde = 0x4;
  const swShowNormal = 1;
  DynamicLibrary.open('ole32.dll').lookupFunction<_CoInitC, _CoInitDart>('CoInitializeEx')(
      nullptr, coinitApartmentThreaded | coinitDisableOle1Dde);
  final shellExecute =
      DynamicLibrary.open('shell32.dll').lookupFunction<_ShellExecuteC, _ShellExecuteDart>('ShellExecuteW');
  final file = path.toNativeUtf16();
  try {
    return shellExecute(0, nullptr, file, nullptr, nullptr, swShowNormal);
  } finally {
    calloc.free(file);
  }
}
