import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PathUtils {
  static Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      // getExternalStorageDirectory() → /sdcard/Android/data/<pkg>/files
      // This is always accessible without extra permissions
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final dir = Directory('${extDir.path}/ApexShare');
        await dir.create(recursive: true);
        return dir.path;
      }
      // Fallback: internal app documents
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/ApexShare');
      await dir.create(recursive: true);
      return dir.path;
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
    if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
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
}
