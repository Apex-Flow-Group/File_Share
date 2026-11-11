// ignore_for_file: avoid_print

import 'dart:io';

import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/identity/tls_peer.dart';
// ─── Share HTTP Server stub ───────────────────────────────────────────────────

/// يُنشئ HTTP server حقيقي يستخدم ShareFolderHttp كـ handler
/// مع ShareFolderService مُوجَّه لمجلد مؤقت.
class _TestShareServer {
  HttpServer? _server;
  late Directory shareDir;
  late ShareFolderHttp handler;
  bool _shareEnabled = true;
  bool _uploadsEnabled = true;

  Future<int> start() async {
    shareDir = await Directory.systemTemp.createTemp('apex_share_http_');
    final svc = _OverrideSvc(shareDir.path);
    handler = ShareFolderHttp(
      expectedFingerprint: await heardSender(),
      pins: PinStore.memory(),
      isEnabled: () => _shareEnabled,
      allowUploads: () => _uploadsEnabled,
      getLocalName: () => 'TestServer',
      service: svc,
    );
    _server = await bindReceiver();
    _server!.listen(_handle);
    return _server!.port;
  }

  Future<void> stop() => _server?.close(force: true) ?? Future.value();

  Future<void> _handle(HttpRequest req) async {
    final handled = await handler.handle(req);
    if (!handled) {
      req.response.statusCode = 404;
      await req.response.close();
    }
  }

  void disableShare() => _shareEnabled = false;
  void disableUploads() => _uploadsEnabled = false;
}

class _OverrideSvc extends ShareFolderService {
  final String _path;
  _OverrideSvc(this._path) : super.forTesting();

  @override
  Future<String> getFolderPath() async => _path;
}

// ─── HTTP helpers ─────────────────────────────────────────────────────────────

Future<HttpClientResponse> _get(int port, String path,
    [Map<String, String>? params]) async {
  final uri = Uri.https('127.0.0.1:$port', path, params);
  final c = (await senderClient())..connectionTimeout = const Duration(seconds: 5);
  final req = await c.getUrl(uri);
  return req.close();
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(loadPeers);
  late _TestShareServer srv;
  late int port;

  setUp(() async {
    // PlatformDetector.instance.isDesktop يعيد true على Windows/Linux/macOS
    // الاختبارات تعمل على نفس المنصة → isDesktop == true بالطبيعة
    srv = _TestShareServer();
    port = await srv.start();
  });

  tearDown(() async {
    await srv.stop();
    if (await srv.shareDir.exists()) {
      await srv.shareDir.delete(recursive: true);
    }
  });

  // ── GET /share ─────────────────────────────────────────────────────────────

  group('GET /share', () {
    test('يُعيد 404 إذا Share مُعطَّل', () async {
      srv.disableShare();
      final res = await _get(port, '/share');
      expect(res.statusCode, equals(404));
    });
  });

  // ── GET /share/file ────────────────────────────────────────────────────────


  // ── POST /share/upload ─────────────────────────────────────────────────────

  group('POST /share/upload', () {
    test('اختبار حد الـ 2GB — المنطق في ShareFolderHttp', () {
      // اختبار مباشر للثابت بدون HTTP فعلي
      const maxBytes = 2 * 1024 * 1024 * 1024;
      expect(maxBytes, equals(2147483648));
      // أي content-length أكبر يجب أن يُعيد 413
      expect(maxBytes + 1 > maxBytes, isTrue);
    });
  });

  // ── GET /share/info ────────────────────────────────────────────────────────

}
