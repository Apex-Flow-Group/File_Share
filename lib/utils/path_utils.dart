import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class PathUtils {
  static const _channel = MethodChannel('com.apex.core/file_ops');

  static Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      try {
        // Get the public Downloads/ApexShare path from native side
        final path = await _channel.invokeMethod<String>('getDownloadsPath');
        if (path != null) {
          final dir = Directory(path);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return path;
        }
      } catch (_) {}
      // Fallback: use public Downloads path directly
      const downloadDir = '/storage/emulated/0/Download/ApexShare';
      final dir = Directory(downloadDir);
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      } catch (_) {
        // Final fallback: app-specific storage
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final fallbackDir = Directory('${extDir.path}/ApexShare');
          await fallbackDir.create(recursive: true);
          return fallbackDir.path;
        }
        final docDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory('${docDir.path}/ApexShare');
        await fallbackDir.create(recursive: true);
        return fallbackDir.path;
      }
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      final dir = Directory('$home/Downloads/ApexShare');
      await dir.create(recursive: true);
      return dir.path;
    } else if (Platform.isWindows) {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/ApexShare');
      await dir.create(recursive: true);
      return dir.path;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/ApexShare');
      await dir.create(recursive: true);
      return dir.path;
    }
  }

  static Future<String> getCategoryPath(String fileName) async {
    final base = await getDownloadPath();
    final category = _getCategory(fileName);
    final dir = Directory('$base/$category');
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Save a file to public Downloads using MediaStore API (Android 10+).
  /// Returns the final path of the saved file.
  /// This method is Google Play compliant — no MANAGE_EXTERNAL_STORAGE needed.
  static Future<String?> saveToPublicDownloads(
      String fileName, String tempFilePath) async {
    if (!Platform.isAndroid) return null;
    try {
      final category = _getCategory(fileName);
      final result = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'sourcePath': tempFilePath,
        'subFolder': category,
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  static String _getCategory(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return 'Images';
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv'].contains(ext)) {
      return 'Videos';
    }
    if (['mp3', 'wav', 'flac', 'm4a', 'aac'].contains(ext)) {
      return 'Audio';
    }
    if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(ext)) {
      return 'Documents';
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return 'Archives';
    }
    if (['apk'].contains(ext)) {
      return 'Apps';
    }
    return 'Others';
  }

  /// Get the category for a file (public accessor)
  static String getCategory(String fileName) => _getCategory(fileName);
}
