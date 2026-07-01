import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// خدمة ضغط المجلدات إلى ملفات ZIP قبل الإرسال
class FolderZipService {
  /// يضغط مجلد كامل إلى ملف ZIP مؤقت
  /// يُرجع مسار ملف ZIP الناتج
  static Future<String> zipFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw Exception('Folder does not exist: $folderPath');
    }

    final folderName = dir.path.split(Platform.pathSeparator).last;
    final archive = Archive();

    // جمع كل الملفات في المجلد بشكل recursive
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath =
            entity.path.substring(dir.path.length + 1).replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        archive.addFile(
          ArchiveFile('$folderName/$relativePath', bytes.length, bytes),
        );
      }
    }

    // إنشاء ملف ZIP مؤقت
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/$folderName.zip';
    final zipData = ZipEncoder().encode(archive);

    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData);

    return zipPath;
  }

  /// حذف ملف ZIP المؤقت بعد الإرسال
  static Future<void> cleanupTemp(String zipPath) async {
    try {
      final file = File(zipPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
