// ignore_for_file: always_put_control_body_on_new_line

import 'dart:convert';
import 'dart:io';

import '../services/desktop_notification_service.dart';
import '../services/share_folder_service.dart';
import '../utils/apex_logger.dart';
import '../utils/platform_detector.dart';

/// يعالج HTTP endpoints الخاصة بمجلد Share.
/// لا يُنشئ server خاصاً به — يتكامل مع server ApexCore الحالي.
///
/// Endpoints:
///   GET  /share          → JSON قائمة الملفات
///   GET  /share/file     → تنزيل ملف (?name=)
///   POST /share/upload   → رفع ملف (?name=&from=)
///   GET  /share/info     → { enabled, fileCount, folderName }
class ShareFolderHttp {
  static const int _maxUploadBytes = 2 * 1024 * 1024 * 1024; // 2 GB

  final ShareFolderService _svc;
  final bool Function() isEnabled;
  final bool Function() allowUploads;
  final String? Function() getLocalName;

  ShareFolderHttp({
    required this.isEnabled,
    required this.allowUploads,
    required this.getLocalName,
    ShareFolderService? service,
  }) : _svc = service ?? ShareFolderService.instance;

  // ─── Router ────────────────────────────────────────────────────────────────

  /// يُعيد true إذا تولّى معالجة الطلب، false إذا لم يكن من اختصاصه.
  Future<bool> handle(HttpRequest req) async {
    final path = req.uri.path;
    if (!path.startsWith('/share')) return false;

    // desktop only
    if (!PlatformDetector.instance.isDesktop) {
      await _notFound(req);
      return true;
    }

    // ميزة مُعطَّلة
    if (!isEnabled()) {
      await _notFound(req);
      return true;
    }

    try {
      if (req.method == 'GET' && path == '/share') {
        await _handleList(req);
      } else if (req.method == 'GET' && path == '/share/file') {
        await _handleDownload(req);
      } else if (req.method == 'POST' && path == '/share/upload') {
        await _handleUpload(req);
      } else if (req.method == 'GET' && path == '/share/info') {
        await _handleInfo(req);
      } else {
        await _notFound(req);
      }
    } catch (e) {
      ApexLogger.instance.log('SHARE_HTTP', '❌ $e', LogLevel.error);
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
    return true;
  }

  // ─── GET /share ────────────────────────────────────────────────────────────

  Future<void> _handleList(HttpRequest req) async {
    final files = await _svc.listFiles();
    final json = files.map((f) => f.toJson()).toList();
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json;
    req.response.write(jsonEncode(json));
    await req.response.close();
  }

  // ─── GET /share/file?name= ─────────────────────────────────────────────────

  Future<void> _handleDownload(HttpRequest req) async {
    final rawName = req.uri.queryParameters['name'] ?? '';
    if (rawName.isEmpty) {
      await _badRequest(req, 'missing name');
      return;
    }

    final safePath = await _svc.resolveSafeFile(rawName);
    if (safePath == null) {
      await _badRequest(req, 'invalid name');
      return;
    }

    final file = File(safePath);
    if (!await file.exists()) {
      await _notFound(req);
      return;
    }

    final length = await file.length();
    // sanitize اسم الملف لـ Content-Disposition
    final safeDisp = rawName.replaceAll('"', '_').replaceAll('\n', '');
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Length', length.toString())
      ..headers.set('Content-Disposition', 'attachment; filename="$safeDisp"');

    await req.response.addStream(file.openRead());
    await req.response.close();

    ApexLogger.instance
        .log('SHARE_HTTP', '⬇ Download: $rawName', LogLevel.info);
  }

  // ─── POST /share/upload?name=&from= ───────────────────────────────────────

  Future<void> _handleUpload(HttpRequest req) async {
    if (!allowUploads()) {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.write(jsonEncode({'error': 'uploads disabled'}));
      await req.response.close();
      return;
    }

    final rawName = req.uri.queryParameters['name'] ?? 'upload';
    final fromDevice = req.uri.queryParameters['from'] ?? 'Unknown';
    final contentLength =
        int.tryParse(req.headers.value('content-length') ?? '') ?? 0;

    if (contentLength > _maxUploadBytes) {
      req.response.statusCode = 413; // Request Entity Too Large
      req.response.write(jsonEncode({'error': 'file exceeds 2 GB limit'}));
      await req.response.close();
      return;
    }

    try {
      final finalPath = await _svc.saveUpload(
        rawName: rawName,
        data: req,
        contentLength: contentLength,
      );
      final savedName = finalPath.split(Platform.pathSeparator).last;

      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'success': true, 'name': savedName}));
      await req.response.close();

      // إشعار
      try {
        await DesktopNotificationService.instance
            .showShareUpload(savedName, fromDevice);
      } catch (_) {
        // الإشعار غير ضروري لإكمال الرفع
      }

      ApexLogger.instance.log('SHARE_HTTP',
          '⬆ Upload: $savedName from $fromDevice', LogLevel.success);
    } catch (e) {
      ApexLogger.instance
          .log('SHARE_HTTP', '❌ Upload error: $e', LogLevel.error);
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.write(jsonEncode({'error': e.toString()}));
        await req.response.close();
      } catch (_) {}
    }
  }

  // ─── GET /share/info ───────────────────────────────────────────────────────

  Future<void> _handleInfo(HttpRequest req) async {
    final files = await _svc.listFiles();
    final folderPath = await _svc.getFolderPath();
    final folderName = folderPath.split(Platform.pathSeparator).last;

    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json;
    req.response.write(jsonEncode({
      'enabled': true,
      'fileCount': files.length,
      'folderName': folderName,
      'allowUploads': allowUploads(),
    }));
    await req.response.close();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _notFound(HttpRequest req) async {
    req.response.statusCode = HttpStatus.notFound;
    await req.response.close();
  }

  Future<void> _badRequest(HttpRequest req, String msg) async {
    req.response
      ..statusCode = HttpStatus.badRequest
      ..write(jsonEncode({'error': msg}));
    await req.response.close();
  }
}
