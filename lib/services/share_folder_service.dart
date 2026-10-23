// ignore_for_file: always_put_control_body_on_new_line

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/apex_logger.dart';
import '../utils/file_utils.dart';
import '../utils/path_utils.dart';

/// معلومات ملف داخل مجلد Share
class ShareFileInfo {
  final String name;
  final int size;
  final DateTime modified;
  final String? mime;

  const ShareFileInfo({
    required this.name,
    required this.size,
    required this.modified,
    this.mime,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'modified': modified.toUtc().toIso8601String(),
        if (mime != null) 'mime': mime,
      };
}

/// خدمة إدارة مجلد Share المشترك.
/// لا تحتوي منطق HTTP — المسؤولية: المسارات، القراءة، الكتابة، الحذف، فتح المجلد.
class ShareFolderService {
  ShareFolderService._();
  static final ShareFolderService instance = ShareFolderService._();

  /// constructor محمي للاختبارات فقط — يتيح subclassing
  @visibleForTesting
  ShareFolderService.forTesting();

  // ─── المسار ───────────────────────────────────────────────────────────────

  /// يُعيد المسار وينشئ المجلد إن لم يوجد.
  Future<String> getFolderPath() => PathUtils.getShareFolderPath();

  Future<Directory> ensureExists() async {
    final path = await getFolderPath();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ─── القراءة ──────────────────────────────────────────────────────────────

  /// يُعيد قائمة الملفات (ملفات فقط — لا مجلدات فرعية) مع معلوماتها.
  Future<List<ShareFileInfo>> listFiles() async {
    final dir = await ensureExists();
    final result = <ShareFileInfo>[];
    await for (final entity in dir.list(recursive: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        final name = entity.path.split(Platform.pathSeparator).last;
        result.add(ShareFileInfo(
          name: name,
          size: stat.size,
          modified: stat.modified,
          mime: _guessMime(name),
        ));
      } catch (e) {
        ApexLogger.instance
            .log('SHARE', 'listFiles skip: $e', LogLevel.warning);
      }
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  // ─── path jail ────────────────────────────────────────────────────────────

  /// يتحقق من أن الاسم آمن ويعيد المسار الكامل داخل Share.
  /// يرفض: ..، /، \، null bytes، مسارات مطلقة.
  /// يرجع null إذا كان الاسم غير آمن.
  Future<String?> resolveSafeFile(String rawName) async {
    // رفض null bytes
    if (rawName.contains('\x00')) return null;
    // رفض traversal
    if (rawName.contains('..')) return null;
    // رفض فواصل المسار
    if (rawName.contains('/') || rawName.contains('\\')) return null;
    // رفض مسارات مطلقة (Windows: C:\ ، Unix: /)
    if (rawName.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(rawName)) {
      return null;
    }
    // تنظيف: أحرف غير مسموح بها في أسماء الملفات
    final sanitized = rawName.replaceAll(RegExp(r'[<>:"|?*]'), '_').trim();
    if (sanitized.isEmpty) return null;

    final folder = await getFolderPath();
    final candidate = '$folder${Platform.pathSeparator}$sanitized';

    // path jail: التأكد أن المسار الحقيقي يبدأ بمسار Share
    final canonical = File(candidate).absolute.path;
    final folderCanonical = Directory(folder).absolute.path;
    if (!canonical.startsWith(folderCanonical)) return null;

    return canonical;
  }

  // ─── الكتابة ──────────────────────────────────────────────────────────────

  /// يحفظ البيانات كملف داخل Share.
  /// يكتب أولاً في ملف مؤقت ثم يُعيد تسميته داخل Share.
  /// إذا كان الاسم موجوداً → name (1).ext وليس overwrite.
  /// يرجع المسار النهائي.
  Future<String> saveUpload({
    required String rawName,
    required Stream<List<int>> data,
    required int contentLength,
    void Function(int received)? onProgress,
  }) async {
    final folder = await getFolderPath();
    final safeName = _sanitizeName(rawName);
    final finalPath = _resolveUniquePath(folder, safeName);

    // اكتب في temp داخل نفس المجلد لضمان atomic rename
    final tempPath = '$finalPath.apex_tmp';
    IOSink? sink;
    try {
      sink = File(tempPath).openWrite(mode: FileMode.write);
      int received = 0;
      await for (final chunk in data) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      await File(tempPath).rename(finalPath);
      ApexLogger.instance.log('SHARE', '✅ Saved: $finalPath', LogLevel.success);
      return finalPath;
    } catch (e) {
      await sink?.close().catchError((_) {});
      try {
        await File(tempPath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  // ─── الحذف ────────────────────────────────────────────────────────────────

  Future<void> deleteFile(String rawName) async {
    final path = await resolveSafeFile(rawName);
    if (path == null) throw Exception('Invalid file name');
    final file = File(path);
    if (!await file.exists()) throw Exception('File not found');
    await file.delete();
    ApexLogger.instance.log('SHARE', '🗑 Deleted: $rawName', LogLevel.info);
  }

  // ─── فتح المجلد ───────────────────────────────────────────────────────────

  Future<void> openInExplorer() async {
    final folder = await getFolderPath();
    // نستخدم dummy file path لـ openFileLocation الذي يفتح المجلد الأب
    final dummyPath = '$folder${Platform.pathSeparator}.apex_placeholder';
    try {
      await FileUtils.openFileLocation(dummyPath);
    } catch (_) {
      // fallback: افتح المجلد مباشرةً
      if (Platform.isWindows) {
        await Process.run('explorer', [folder]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folder]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folder]);
      }
    }
  }

  // ─── مساعدات ──────────────────────────────────────────────────────────────

  /// ينظّف اسم الملف من الأحرف غير المسموح بها.
  static String _sanitizeName(String raw) {
    var name = raw
        .replaceAll('\x00', '')
        .replaceAll('..', '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(RegExp(r'[<>:"|?*]'), '_')
        .trim();
    return name.isEmpty ? 'upload' : name;
  }

  /// يُعيد مساراً فريداً — إذا وجد name.ext يجرب name (1).ext وهكذا.
  static String _resolveUniquePath(String folder, String fileName) {
    var candidate = '$folder${Platform.pathSeparator}$fileName';
    if (!File(candidate).existsSync()) return candidate;

    final dot = fileName.lastIndexOf('.');
    final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot >= 0 ? fileName.substring(dot) : '';

    int counter = 1;
    while (true) {
      candidate = '$folder${Platform.pathSeparator}$base ($counter)$ext';
      if (!File(candidate).existsSync()) return candidate;
      counter++;
    }
  }

  static String? _guessMime(String fileName) {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'flac': 'audio/flac',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      'apk': 'application/vnd.android.package-archive',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return map[ext];
  }
}
