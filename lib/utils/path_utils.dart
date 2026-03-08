import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PathUtils {
  static Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      try {
        // محاولة استخدام مجلد Downloads العام
        final dir = Directory('/storage/emulated/0/Download/ApexShare');
        if (await dir.exists() || await _tryCreateDirectory(dir)) {
          return dir.path;
        }
      } catch (e) {
        // تجاهل الخطأ والمحاولة التالية
      }
      
      try {
        // محاولة استخدام مجلد Documents العام
        final dir = Directory('/storage/emulated/0/Documents/ApexShare');
        if (await dir.exists() || await _tryCreateDirectory(dir)) {
          return dir.path;
        }
      } catch (e) {
        // تجاهل الخطأ والمحاولة التالية
      }
      
      try {
        // استخدام المجلد الخارجي للتطبيق (يمكن الوصول إليه)
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          // استخدام المجلد الرئيسي بدلاً من data
          final publicPath = dir.path.replaceAll(
            RegExp(r'/Android/data/[^/]+/files'),
            '/ApexShare',
          );
          final publicDir = Directory(publicPath);
          if (await _tryCreateDirectory(publicDir)) {
            return publicPath;
          }
          // Fallback للمجلد الخارجي العادي
          return '${dir.path}/ApexShare';
        }
      } catch (e) {
        // تجاهل الخطأ
      }
      
      // Fallback النهائي للمجلد الداخلي
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/ApexShare';
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return '$home/Downloads/ApexShare';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/ApexShare';
    }
  }
  
  static Future<bool> _tryCreateDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<String> getCategoryPath(String fileName) async {
    final category = _getCategory(fileName);
    final basePath = await getDownloadPath();
    return '$basePath/$category';
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
