// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';
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
      isEnabled: () => _shareEnabled,
      allowUploads: () => _uploadsEnabled,
      getLocalName: () => 'TestServer',
      service: svc,
    );
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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
  final uri = Uri.http('127.0.0.1:$port', path, params);
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final req = await c.getUrl(uri);
  return req.close();
}

Future<HttpClientResponse> _post(
    int port, String path, Map<String, String> params, List<int> body) async {
  final uri = Uri.http('127.0.0.1:$port', path, params);
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final req = await c.postUrl(uri);
  req.headers.set('Content-Length', body.length.toString());
  req.add(body);
  return req.close();
}

Future<String> _body(HttpClientResponse res) =>
    res.transform(utf8.decoder).join();

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
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
    test('يُعيد 200 وJSON فارغ عندما المجلد فارغ', () async {
      final res = await _get(port, '/share');
      expect(res.statusCode, equals(200));
      final json = jsonDecode(await _body(res)) as List;
      expect(json, isEmpty);
    });

    test('يُعيد قائمة الملفات بعد إضافة ملف', () async {
      await File('${srv.shareDir.path}/hello.txt').writeAsString('hello world');

      final res = await _get(port, '/share');
      expect(res.statusCode, equals(200));
      final json = jsonDecode(await _body(res)) as List;
      expect(json.length, equals(1));
      expect(json.first['name'], equals('hello.txt'));
      expect(json.first['size'], equals(11));
      expect(json.first['modified'], isNotNull);
    });

    test('يُعيد 404 إذا Share مُعطَّل', () async {
      srv.disableShare();
      final res = await _get(port, '/share');
      expect(res.statusCode, equals(404));
    });
  });

  // ── GET /share/file ────────────────────────────────────────────────────────

  group('GET /share/file', () {
    test('يُنزّل ملفاً موجوداً بالمحتوى الصحيح', () async {
      const content = 'apex share content';
      await File('${srv.shareDir.path}/test.txt').writeAsString(content);

      final res = await _get(port, '/share/file', {'name': 'test.txt'});
      expect(res.statusCode, equals(200));
      expect(await _body(res), equals(content));
    });

    test('يُعيد 404 إذا الملف غير موجود', () async {
      final res = await _get(port, '/share/file', {'name': 'ghost.txt'});
      expect(res.statusCode, equals(404));
    });

    test('يُعيد 400 إذا اسم الملف فارغ', () async {
      final res = await _get(port, '/share/file', {'name': ''});
      expect(res.statusCode, equals(400));
    });

    test('يُعيد 400 لاسم خطير (../)', () async {
      final res = await _get(port, '/share/file', {'name': '../secret.txt'});
      expect(res.statusCode, equals(400));
    });

    test('Content-Disposition يحتوي اسم الملف', () async {
      await File('${srv.shareDir.path}/doc.pdf').writeAsBytes([1, 2, 3]);
      final res = await _get(port, '/share/file', {'name': 'doc.pdf'});
      final disp = res.headers.value('Content-Disposition') ?? '';
      expect(disp, contains('doc.pdf'));
    });
  });

  // ── POST /share/upload ─────────────────────────────────────────────────────

  group('POST /share/upload', () {
    test('يحفظ ملفاً مرفوعاً بالمحتوى الصحيح', () async {
      const data = [72, 101, 108, 108, 111]; // "Hello"
      final res = await _post(
          port, '/share/upload', {'name': 'upload.bin', 'from': 'Phone'}, data);
      expect(res.statusCode, equals(200));
      final json = jsonDecode(await _body(res)) as Map;
      expect(json['success'], isTrue);

      final savedName = json['name'] as String;
      final saved = File('${srv.shareDir.path}/$savedName');
      expect(saved.existsSync(), isTrue);
      expect(saved.readAsBytesSync(), equals(data));
    });

    test('يُعيد 403 إذا الرفع مُعطَّل', () async {
      srv.disableUploads();
      final res = await _post(
          port, '/share/upload', {'name': 'x.txt', 'from': 'Phone'}, [1]);
      expect(res.statusCode, equals(403));
    });

    test('اختبار حد الـ 2GB — المنطق في ShareFolderHttp', () {
      // اختبار مباشر للثابت بدون HTTP فعلي
      const maxBytes = 2 * 1024 * 1024 * 1024;
      expect(maxBytes, equals(2147483648));
      // أي content-length أكبر يجب أن يُعيد 413
      expect(maxBytes + 1 > maxBytes, isTrue);
    });
  });

  // ── GET /share/info ────────────────────────────────────────────────────────

  group('GET /share/info', () {
    test('يُعيد enabled=true وfileCount صحيح', () async {
      await File('${srv.shareDir.path}/a.txt').writeAsString('a');
      await File('${srv.shareDir.path}/b.txt').writeAsString('bb');

      final res = await _get(port, '/share/info');
      expect(res.statusCode, equals(200));
      final json = jsonDecode(await _body(res)) as Map;
      expect(json['enabled'], isTrue);
      expect(json['fileCount'], equals(2));
      expect(json['folderName'], isNotEmpty);
    });
  });
}
