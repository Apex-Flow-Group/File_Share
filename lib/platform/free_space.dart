import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

/// Free bytes on the disk that holds [path], as the current user may use
/// them. Null when it cannot be read: the batch is then not refused for
/// space, rather than refused on a wrong number.
Future<int?> freeBytesAt(String path) async {
  try {
    if (Platform.isAndroid) {
      return await const MethodChannel('com.apex.core/file_ops').invokeMethod<int>('getFreeBytes');
    }
    if (Platform.isLinux) {
      return _linux(path);
    }
    if (Platform.isWindows) {
      return _windows(path);
    }
  } catch (_) {}
  return null;
}

typedef _StatvfsC = Int32 Function(Pointer<Utf8> path, Pointer<Uint64> buf);
typedef _StatvfsDart = int Function(Pointer<Utf8> path, Pointer<Uint64> buf);

/// glibc statvfs on 64-bit Linux: every field before f_bavail is 8 bytes, so
/// f_frsize is word 1 and f_bavail word 4. 32-bit layouts differ: no reading.
int? _linux(String path) {
  if (sizeOf<IntPtr>() != 8) {
    return null;
  }
  final statvfs = DynamicLibrary.process().lookupFunction<_StatvfsC, _StatvfsDart>('statvfs');
  final cPath = path.toNativeUtf8();
  final buf = calloc<Uint64>(32);
  try {
    if (statvfs(cPath, buf) != 0) {
      return null;
    }
    return buf[1] * buf[4];
  } finally {
    calloc.free(cPath);
    calloc.free(buf);
  }
}

typedef _FreeSpaceC = Int32 Function(
    Pointer<Utf16> dir, Pointer<Uint64> toCaller, Pointer<Uint64> total, Pointer<Uint64> totalFree);
typedef _FreeSpaceDart = int Function(
    Pointer<Utf16> dir, Pointer<Uint64> toCaller, Pointer<Uint64> total, Pointer<Uint64> totalFree);

/// GetDiskFreeSpaceExW: the first number respects the user's disk quota.
int? _windows(String path) {
  final fn = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<_FreeSpaceC, _FreeSpaceDart>('GetDiskFreeSpaceExW');
  final dir = path.toNativeUtf16();
  final out = calloc<Uint64>(3);
  try {
    if (fn(dir, out, out + 1, out + 2) == 0) {
      return null;
    }
    return out[0];
  } finally {
    calloc.free(dir);
    calloc.free(out);
  }
}
