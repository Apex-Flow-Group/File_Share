import 'dart:io';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';

class FileStorageService {
  Future<List<FileSystemEntity>> getReceivedFiles({int? limit}) async {
    try {
      final basePath = await PathUtils.getDownloadPath();
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) {
        return [];
      }

      final files = <FileSystemEntity>[];
      await for (final entity
          in baseDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          // تحقق من أن الملف فعلاً موجود وقابل للقراءة
          try {
            final stat = await entity.stat();
            if (stat.size >= 0) {
              files.add(entity);
            }
          } catch (_) {
            // تجاهل الملفات التي لا يمكن قراءتها
          }
        }
      }

      // ترتيب حسب تاريخ التعديل - مع حماية من الأخطاء
      files.sort((a, b) {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          return 0;
        }
      });
      return limit != null ? files.take(limit).toList() : files;
    } catch (e) {
      ApexLogger.instance
          .log('STORAGE', '❌ فشل قراءة الملفات: $e', LogLevel.error);
      return [];
    }
  }
}
