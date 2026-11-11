// ignore_for_file: always_put_control_body_on_new_line

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../features/identity/caller.dart';
import '../features/identity/pin_store.dart';
import '../features/share/logic/share_access.dart';
import '../models/device.dart';
import '../services/desktop_notification_service.dart';
import '../services/share_folder_service.dart';
import '../utils/apex_logger.dart';
import '../utils/platform_detector.dart';
import 'core_models.dart';
import 'one_question.dart';
import 'protocol/apex_protocol.dart';
import 'protocol/transfer_rules.dart';
import 'text/clean_label.dart';

/// يعالج HTTP endpoints الخاصة بمجلد Share.
/// لا يُنشئ server خاصاً به — يتكامل مع server ApexCore الحالي.
///
/// Every route needs a client certificate and the protocol version;
/// /share/access needs the certificate discovery heard from the id it gives,
/// and every other route a token the user's agreement issued to that address
/// and certificate.
///
/// Endpoints:
///   POST /share/access   → يسأل المستخدم ويُرجع { accepted, token }
///   GET  /share          → JSON قائمة الملفات
///   GET  /share/file     → تنزيل ملف (?name=)
///   POST /share/upload   → رفع ملف (?name=)
///   GET  /share/info     → { enabled, fileCount, folderName }
class ShareFolderHttp {
  static const accessPath = '/share/access';
  static const listPath = '/share';
  static const filePath = '/share/file';
  static const uploadPath = '/share/upload';

  static const _accessBodyLimit = 4096;

  final ShareFolderService _svc;
  final bool Function() isEnabled;
  final bool Function() allowUploads;
  final String? Function() getLocalName;

  /// Asks the user; with nobody to ask, no device gets in.
  final void Function(ConnectionRequest)? onAccessRequest;
  final ExpectedFingerprint expectedFingerprint;

  /// Written when the user lets a device in.
  final PinStore pins;
  final Duration decisionTimeout;
  final int maxUploadBytes;
  final ShareAccess _access;
  final OneQuestion _question;

  /// Error code when the folder is off, so the asker is not told to update.
  static const shareOff = 'share_off';

  /// Call when the user turns the folder off: no earlier agreement survives.
  void revokeAll() => _access.revokeAll();

  ShareFolderHttp({
    required this.isEnabled,
    required this.allowUploads,
    required this.getLocalName,
    required this.expectedFingerprint,
    required this.pins,
    ShareFolderService? service,
    ShareAccess? access,
    OneQuestion? question,
    this.onAccessRequest,
    this.decisionTimeout = TransferRules.decisionTimeout,
    this.maxUploadBytes = 2 * 1024 * 1024 * 1024,
  })  : _svc = service ?? ShareFolderService.instance,
        _access = access ?? ShareAccess(),
        _question = question ?? OneQuestion();

  // ─── Router ────────────────────────────────────────────────────────────────

  /// يُعيد true إذا تولّى معالجة الطلب، false إذا لم يكن من اختصاصه.
  Future<bool> handle(HttpRequest req) async {
    final path = req.uri.path;
    if (path != listPath && !path.startsWith('$listPath/')) return false;

    final fingerprint = callerFingerprint(req);
    if (fingerprint == null) {
      await _json(req, HttpStatus.upgradeRequired,
          {'error': ApexProtocol.updateRequired, 'version': ApexProtocol.version});
      return true;
    }

    // desktop only
    if (!PlatformDetector.instance.isDesktop) {
      await _notFound(req);
      return true;
    }

    // ميزة مُعطَّلة
    if (!isEnabled()) {
      revokeAll();
      await _json(req, HttpStatus.notFound, {'error': shareOff});
      return true;
    }

    if (!ApexProtocol.accepts(req.headers.value(ApexProtocol.versionHeader))) {
      await _json(req, HttpStatus.upgradeRequired,
          {'error': ApexProtocol.updateRequired, 'version': ApexProtocol.version});
      return true;
    }

    try {
      final address = req.connectionInfo?.remoteAddress.address ?? '';
      if (req.method == 'POST' && path == accessPath) {
        await _handleAccess(req, address, fingerprint);
        return true;
      }
      final grant = _access.check(req.headers.value(ApexProtocol.tokenHeader), address, fingerprint);
      if (grant == null) {
        await _json(req, HttpStatus.forbidden, {'error': 'not_allowed'});
        return true;
      }
      if (req.method == 'GET' && path == listPath) {
        await _handleList(req);
      } else if (req.method == 'GET' && path == filePath) {
        await _handleDownload(req);
      } else if (req.method == 'POST' && path == uploadPath) {
        await _handleUpload(req, grant);
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

  // ─── POST /share/access ────────────────────────────────────────────────────

  Future<void> _handleAccess(HttpRequest req, String address, String fingerprint) async {
    final body = await _readBody(req);
    final id = cleanDeviceId(body?['id']);
    if (id == null || expectedFingerprint(id, address) != fingerprint) {
      await _json(req, HttpStatus.forbidden, {'error': ApexProtocol.wrongIdentity});
      return;
    }
    final rawName = body?['name'];
    final name = cleanLabel(rawName is String ? rawName : null);
    final shown = name.isEmpty ? address : name;
    final uploads = allowUploads();
    final answer = await _ask(id, shown, address, fingerprint, uploads);
    if (answer != _Answer.accepted) {
      await _json(req, HttpStatus.ok,
          {'accepted': false, 'reason': answer == _Answer.refused ? 'refused' : 'no_answer'});
      return;
    }
    await pins.pin(id, fingerprint);
    await _json(req, HttpStatus.ok, {
      'accepted': true,
      'uploads': uploads,
      'token': _access.admit(address, shown, fingerprint, uploads: uploads),
    });
  }

  /// One question at a time: a new one must not appear under the finger that
  /// is about to press Accept on the last.
  /// Busy, nobody to ask and no answer in time are not a refusal: the asker
  /// is told to try again, not that the owner said no.
  Future<_Answer> _ask(String id, String name, String address, String fingerprint, bool uploads) async {
    final ask = onAccessRequest;
    if (ask == null || !_question.take()) return _Answer.none;
    final answer = Completer<_Answer>();
    final request = ConnectionRequest(
      device: Device(id: id, name: name, type: 'unknown', ip: address, fingerprint: fingerprint),
      fingerprint: fingerprint,
      keyChanged: pins.keyChanged(id, fingerprint),
      fileName: '',
      fileCount: 0,
      kind: RequestKind.shareFolder,
      allowsUploads: uploads,
      onResponse: (v) {
        if (!answer.isCompleted) answer.complete(v ? _Answer.accepted : _Answer.refused);
      },
    );
    try {
      ask(request);
      return await answer.future.timeout(decisionTimeout, onTimeout: () => _Answer.none);
    } finally {
      _question.release();
      request.close();
    }
  }

  Future<Map?> _readBody(HttpRequest req) async {
    if (req.contentLength > _accessBodyLimit) return null;
    final bytes = <int>[];
    await for (final chunk in req) {
      bytes.addAll(chunk);
      if (bytes.length > _accessBodyLimit) return null;
    }
    try {
      final json = jsonDecode(utf8.decode(bytes));
      return json is Map ? json : null;
    } on FormatException {
      return null;
    }
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

  // ─── POST /share/upload?name= ─────────────────────────────────────────────

  Future<void> _handleUpload(HttpRequest req, ShareGrant grant) async {
    // The user agreed to downloads only if uploads were off when asked.
    if (!allowUploads() || !grant.uploads) {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.write(jsonEncode({'error': 'uploads disabled'}));
      await req.response.close();
      return;
    }

    final rawName = req.uri.queryParameters['name'] ?? '';
    // The name shown is the one the user agreed to, never a new claim.
    final fromDevice = '${grant.name} (${grant.address})';
    final contentLength = req.contentLength;

    if (contentLength < 0) {
      await _json(req, HttpStatus.lengthRequired, {'error': 'length_required'});
      return;
    }
    if (contentLength > maxUploadBytes) {
      await _json(req, HttpStatus.requestEntityTooLarge, {'error': 'too_large'});
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
    } on UploadSizeMismatch {
      await _json(req, HttpStatus.badRequest, {'error': 'size'});
    } catch (e) {
      ApexLogger.instance
          .log('SHARE_HTTP', '❌ Upload error: $e', LogLevel.error);
      await _json(req, HttpStatus.internalServerError, {'error': 'failed'});
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

  Future<void> _json(HttpRequest req, int status, Map<String, Object?> body) async {
    try {
      req.response
        ..statusCode = status
        ..persistentConnection = status < 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    } catch (_) {
      // The device is gone; nothing to tell.
    }
  }

  Future<void> _badRequest(HttpRequest req, String msg) async {
    req.response
      ..statusCode = HttpStatus.badRequest
      ..write(jsonEncode({'error': msg}));
    await req.response.close();
  }
}

enum _Answer { accepted, refused, none }
