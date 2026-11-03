import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/private_temp.dart';

/// خدمة ضغط المجلدات إلى ملفات ZIP قبل الإرسال
class FolderZipService {
  static const _prefix = 'apex_zip_';

  /// A zip folder this old was left by a crash or a killed app, not by a
  /// zip still being written.
  static const _staleAfter = Duration(days: 1);

  /// Zips [folderPath] into "<folder>.zip" inside a fresh folder only this
  /// user can open, and returns its path. [tempRoot] defaults to the app's
  /// temporary folder.
  ///
  /// Files are stored, not deflated, and copied in 1 MB chunks: the archive
  /// package deflates each file whole in memory, so a 400 MB file raised peak
  /// memory by 546 MB. Only free space limits the folder now. The work runs in
  /// another isolate so the screen keeps moving, and a failed zip leaves
  /// nothing behind.
  static Future<String> zipFolder(String folderPath, {Directory? tempRoot}) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw FileSystemException('Folder does not exist', folderPath);
    }
    final root = tempRoot ?? await getTemporaryDirectory();
    await _removeStale(root);
    final work = await createPrivateTemp(root, _prefix);
    final name = _lastSegment(dir.path);
    final zipPath = '${work.path}${Platform.pathSeparator}$name.zip';
    try {
      await Isolate.run(() => _writeZip(dir.path, name, zipPath));
      return zipPath;
    } catch (_) {
      await work.delete(recursive: true);
      rethrow;
    }
  }

  /// Removes the zip and the folder [zipFolder] made for it.
  static Future<void> cleanupTemp(String zipPath) async {
    try {
      final file = File(zipPath);
      final parent = file.parent;
      if (_lastSegment(parent.path).startsWith(_prefix)) {
        await parent.delete(recursive: true);
      } else if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static void _writeZip(String folderPath, String name, String zipPath) {
    final output = OutputFileStream(zipPath);
    try {
      final encoder = ZipEncoder()..startEncode(output);
      // followLinks: false — a link may point outside the folder the user chose.
      final entries = Directory(folderPath).listSync(recursive: true, followLinks: false);
      for (final e in entries) {
        final relative = e.path.substring(folderPath.length + 1).replaceAll(r'\', '/');
        final entryName = '$name/$relative';
        final stat = e.statSync();
        final modified = stat.modified.millisecondsSinceEpoch ~/ 1000;
        if (e is Directory) {
          // Stored too: an empty "deflated" entry is invalid and fails unzip -t.
          encoder.add(ArchiveFile.directory(entryName)
            ..compression = CompressionType.none
            ..mode = stat.mode
            ..lastModTime = modified);
        } else if (e is File) {
          final input = InputFileStream(e.path);
          try {
            encoder.add(
              ArchiveFile.stream(entryName, input)
                ..compression = CompressionType.none
                ..mode = stat.mode
                ..lastModTime = modified,
              autoClose: false,
            );
          } finally {
            input.closeSync();
          }
        }
      }
      encoder.endEncode();
    } finally {
      output.closeSync();
    }
  }

  static Future<void> _removeStale(Directory root) async {
    if (!await root.exists()) {
      return;
    }
    final now = DateTime.now();
    await for (final e in root.list(followLinks: false)) {
      if (e is Directory && _lastSegment(e.path).startsWith(_prefix)) {
        try {
          if (now.difference((await e.stat()).modified) > _staleAfter) {
            await e.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  static String _lastSegment(String path) =>
      path.split(RegExp(r'[/\\]')).lastWhere((s) => s.isNotEmpty, orElse: () => 'folder');
}
