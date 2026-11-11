import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../platform/reveal_in_folder.dart';

class FileUtils {

  static const _channel = MethodChannel('com.apex.core/file_ops');

  /// A saved path as every screen shows it: without the Android storage root,
  /// and isolated left-to-right so a leading "/" does not jump to the other
  /// end of an Arabic sentence.
  static String displayPath(String path) =>
      '${String.fromCharCode(0x2066)}'
      '${path.replaceFirst('/storage/emulated/0/', '')}'
      '${String.fromCharCode(0x2069)}';

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

    // Never through cmd: it runs "&" in a name, so "report&calc" starts calc.
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [windowsPath(filePath)]);
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

  /// Opens the folder that holds [filePath], or throws [FolderOpenError].
  /// Never opens the file instead: for an APK that starts installing it.
  static Future<void> openFileLocation(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openFileLocation', {'path': filePath});
        return;
      } on PlatformException catch (e) {
        throw FolderOpenError(missing: e.code == 'FOLDER_MISSING');
      }
    }
    final dir = File(filePath).parent;
    if (!await dir.exists()) {
      throw const FolderOpenError(missing: true);
    }
    final revealed = await revealOnDesktop(filePath);
    if (revealed != null) {
      if (!revealed) {
        throw const FolderOpenError();
      }
      return;
    }
    final result = await OpenFilex.open(dir.path);
    if (result.type == ResultType.noAppToOpen || result.type == ResultType.error) {
      throw const FolderOpenError();
    }
  }

  /// Opens [dirPath] itself, with nothing selected in it.
  static Future<void> openFolder(String dirPath) async {
    if (!await Directory(dirPath).exists()) {
      throw const FolderOpenError(missing: true);
    }
    final opened = await openFolderOnDesktop(dirPath);
    if (opened != null) {
      if (!opened) {
        throw const FolderOpenError();
      }
      return;
    }
    // The Android side opens the parent of the path it is given.
    await openFileLocation('$dirPath/.');
  }
}

/// The folder could not be opened: [missing] when it was deleted or moved,
/// otherwise no app on the device opens folders.
class FolderOpenError implements Exception {
  const FolderOpenError({this.missing = false});

  final bool missing;
}
