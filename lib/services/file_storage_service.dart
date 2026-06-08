import 'dart:io';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';

class FileStorageService {
  Future<String?> saveFile(String fileName, List<int> data) async {
    try {
      final dirPath = await PathUtils.getCategoryPath(fileName);
      final dir = Directory(dirPath);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$dirPath/$fileName';
      final file = File(filePath);

      ApexLogger.instance.log(
          'STORAGE',
          '💾 حفظ ${_formatSize(data.length)} إلى: $filePath',
          LogLevel.warning);
      await file.writeAsBytes(data);

      final savedSize = await file.length();
      ApexLogger.instance.log('STORAGE',
          '✅ تم حفظ الملف: ${_formatSize(savedSize)}', LogLevel.success);

      // Scan file for Android
      if (Platform.isAndroid) {
        await _scanFile(filePath);
      }

      return filePath;
    } catch (e) {
      ApexLogger.instance.log('STORAGE', '❌ فشل حفظ الملف: $e', LogLevel.error);
      return null;
    }
  }

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

  Future<void> _scanFile(String filePath) async {
    try {
      // Use MediaScannerConnection via platform channel is better,
      // but as a fallback we use the broadcast intent (works on older Android)
      await Process.run('am', [
        'broadcast',
        '-a',
        'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d',
        'file://$filePath'
      ]);
    } catch (_) {}
    // Also try the new way for Android 13+
    try {
      await Process.run('content', [
        'call',
        '--uri',
        'content://media/none/none',
        '--method',
        'scan_volume',
        '--arg',
        'external_primary'
      ]);
    } catch (_) {}
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}
