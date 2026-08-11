import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

class FileUtils {

  static const _channel = MethodChannel('com.apex.core/file_ops');

  static String formatSize(int bytes) {
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
  
  static IconData getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return Icons.image;
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv'].contains(ext)) {
      return Icons.video_file;
    }
    if (['mp3', 'wav', 'flac', 'm4a', 'aac'].contains(ext)) {
      return Icons.audio_file;
    }
    if (['pdf'].contains(ext)) {
      return Icons.picture_as_pdf;
    }
    if (['doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return Icons.description;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip;
    }
    if (['apk'].contains(ext)) {
      return Icons.android;
    }
    return Icons.insert_drive_file;
  }
  
  static String getFileCategory(String fileName) {
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
  
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) {
      return 'الآن';
    }
    if (diff.inHours < 1) {
      return 'منذ ${diff.inMinutes} دقيقة';
    }
    if (diff.inDays < 1) {
      return 'منذ ${diff.inHours} ساعة';
    }
    return 'منذ ${diff.inDays} يوم';
  }
  
  static Future<void> openFile(String filePath) async {
    if (Platform.isAndroid) {
      try {
        // Use native FileProvider to get content:// URI - works on all Android versions
        await _channel.invokeMethod('openFile', {'path': filePath});
        return;
      } catch (_) {
        // fallback to open_filex
      }
    }

    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
      return;
    }

    if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
      return;
    }

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
      throw Exception(result.message);
    }
  }

  static Future<void> openFileLocation(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openFileLocation', {'path': filePath});
        return;
      } catch (_) {
        // fallback
      }
    }
    final dir = File(filePath).parent;
    if (!await dir.exists()) {
      throw Exception('المجلد غير موجود');
    }
    final result = await OpenFilex.open(dir.path);
    if (result.type == ResultType.noAppToOpen || result.type == ResultType.error) {
      final files = await dir.list().toList();
      if (files.isNotEmpty) {
        await OpenFilex.open(files.first.path);
      } else {
        throw Exception('المجلد فارغ');
      }
    }
  }
  
  static Future<void> shareFile(String filePath) async {
    try {
      if (Platform.isAndroid) {
        await Process.run('am', ['start', '-a', 'android.intent.action.SEND', '-t', '*/*', '--eu', 'android.intent.extra.STREAM', 'file://$filePath']);
      }
    } catch (e) {
      rethrow;
    }
  }
}
