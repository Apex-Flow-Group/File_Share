import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/share/logic/share_access.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';

/// Any certificate's fingerprint: these tests are about tokens, not identity.
const _fp = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

/// A real server on 127.0.0.1 with the real handler and a scripted user.
class _Server {
  late Directory dir;
  late HttpServer server;
  late ShareFolderHttp share;
  final asked = <ConnectionRequest>[];
  bool? answer = true;
  bool enabled = true;
  bool uploads = true;

  Future<void> start({int maxUploadBytes = 1024}) async {
    dir = await Directory.systemTemp.createTemp('apex_share_access_');
    File('${dir.path}/salary.xlsx').writeAsStringSync('private');
    share = ShareFolderHttp(
      expectedFingerprint: await heardSender(),
      pins: PinStore.memory(),
      isEnabled: () => enabled,
      allowUploads: () => uploads,
      getLocalName: () => 'Office PC',
      service: _TempShareService(dir.path),
      onAccessRequest: (r) {
        asked.add(r);
        final a = answer;
        if (a != null) {
          r.onResponse(a);
        }
      },
      decisionTimeout: const Duration(milliseconds: 200),
      maxUploadBytes: maxUploadBytes,
    );
    server = await bindReceiver();
    server.listen((req) async {
      if (!await share.handle(req)) {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
  }

  Future<void> stop() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  }

  List<String> get names =>
      dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList();

  Future<({int status, String body})> send(
    String method,
    String path, {
    Map<String, String>? query,
    List<int>? body,
    String? token,
    Object? version = ApexProtocol.version,
    bool chunked = false,
  }) async {
    final client = await senderClient();
    try {
      final req = await client.openUrl(method, Uri.https('127.0.0.1:${server.port}', path, query));
      if (version != null) {
        req.headers.set(ApexProtocol.versionHeader, '$version');
      }
      if (token != null) {
        req.headers.set(ApexProtocol.tokenHeader, token);
      }
      if (body != null) {
        if (!chunked) {
          req.contentLength = body.length;
        }
        req.add(body);
      }
      final res = await req.close();
      return (status: res.statusCode, body: await res.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> askAccess([String name = 'Phone']) async {
    final res = await send('POST', ShareFolderHttp.accessPath,
        body: utf8.encode(jsonEncode({'id': 'phone', 'name': name})));
    final json = jsonDecode(res.body);
    return json is Map && json['accepted'] == true ? json['token'] as String? : null;
  }
}

void main() {
  setUpAll(loadPeers);
  late _Server s;

  setUp(() async {
    s = _Server();
    await s.start();
  });

  tearDown(() => s.stop());

  group('a device the user never accepted', () {
    test('cannot list, download, read the info or upload, even with the right version',
        () async {
      for (final path in ['/share', '/share/info']) {
        expect((await s.send('GET', path)).status, HttpStatus.forbidden, reason: path);
      }
      expect((await s.send('GET', '/share/file', query: {'name': 'salary.xlsx'})).status,
          HttpStatus.forbidden);
      final up = await s.send('POST', '/share/upload',
          query: {'name': 'x.txt'}, body: utf8.encode('x'));
      expect(up.status, HttpStatus.forbidden);
      expect(s.names, isNot(contains('x.txt')));
      expect(s.asked, isEmpty, reason: 'Only /share/access asks the user.');
    });

    test('a made-up token opens nothing', () async {
      expect((await s.send('GET', '/share', token: 'made-up')).status, HttpStatus.forbidden);
    });

    test('a refused request gives no token', () async {
      s.answer = false;
      expect(await s.askAccess(), isNull);
      expect(s.asked, hasLength(1));
    });

    test('no answer within the decision time is a refusal', () async {
      s.answer = null;
      expect(await s.askAccess(), isNull);
    });

    test('with nobody to ask, access is refused', () async {
      final share = ShareFolderHttp(
        expectedFingerprint: await heardSender(),
        pins: PinStore.memory(),
        isEnabled: () => true,
        allowUploads: () => true,
        getLocalName: () => 'Office PC',
        service: _TempShareService(s.dir.path),
      );
      s.share = share;
      expect(await s.askAccess(), isNull);
    });
  });

  group('the request the user sees', () {
    test('shows the cleaned name and the real address', () async {
      s.answer = false;
      await s.askAccess('Boss\nPC${String.fromCharCode(0x202E)}');
      final r = s.asked.single;
      expect(r.kind, RequestKind.shareFolder);
      expect(r.device.name, 'Boss PC');
      expect(r.device.ip, '127.0.0.1');
    });
  });

  group('the version', () {
    test('every route refuses a request with no version or another one, unasked', () async {
      final token = await s.askAccess();
      s.asked.clear();
      for (final version in [null, ApexProtocol.version - 1]) {
        for (final (method, path) in [
          ('POST', ShareFolderHttp.accessPath),
          ('GET', '/share'),
          ('GET', '/share/file'),
          ('GET', '/share/info'),
          ('POST', '/share/upload'),
        ]) {
          final res = await s.send(method, path,
              query: {'name': 'salary.xlsx'}, token: token, version: version, body: [1]);
          expect(res.status, HttpStatus.upgradeRequired, reason: '$path v$version');
          expect(jsonDecode(res.body)['error'], ApexProtocol.updateRequired);
        }
      }
      expect(s.asked, isEmpty);
      expect(s.names, ['salary.xlsx']);
    });
  });

  group('a device the user accepted', () {
    late String token;

    setUp(() async {
      token = (await s.askAccess())!;
    });

    test('lists the folder', () async {
      final res = await s.send('GET', '/share', token: token);
      expect(res.status, HttpStatus.ok);
      final list = jsonDecode(res.body) as List;
      expect(list.single['name'], 'salary.xlsx');
      expect(list.single['size'], 7);
      expect(list.single['modified'], isNotNull);
    });

    test('downloads a file with its content and name', () async {
      final client = await senderClient();
      final req = await client.getUrl(
          Uri.https('127.0.0.1:${s.server.port}', '/share/file', {'name': 'salary.xlsx'}));
      req.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..set(ApexProtocol.tokenHeader, token);
      final res = await req.close();
      expect(res.statusCode, HttpStatus.ok);
      expect(res.headers.value('Content-Disposition'), contains('salary.xlsx'));
      expect(await res.transform(utf8.decoder).join(), 'private');
      client.close(force: true);
    });

    test('a missing, empty or climbing name is refused', () async {
      expect((await s.send('GET', '/share/file', query: {'name': 'ghost.txt'}, token: token)).status,
          HttpStatus.notFound);
      expect((await s.send('GET', '/share/file', query: {'name': ''}, token: token)).status,
          HttpStatus.badRequest);
      expect(
          (await s.send('GET', '/share/file', query: {'name': '../secret.txt'}, token: token))
              .status,
          HttpStatus.badRequest);
    });

    test('reads the info', () async {
      final res = await s.send('GET', '/share/info', token: token);
      expect(res.status, HttpStatus.ok);
      expect(jsonDecode(res.body)['fileCount'], 1);
    });

    test('uploads a file, under a cleaned name', () async {
      final res = await s.send('POST', '/share/upload',
          query: {'name': '../up:load.txt'}, body: utf8.encode('hello'), token: token);
      expect(res.status, HttpStatus.ok);
      final saved = jsonDecode(res.body)['name'] as String;
      expect(saved, isNot(contains('/')));
      expect(saved, isNot(contains(':')));
      expect(File('${s.dir.path}/$saved').readAsStringSync(), 'hello');
    });

    test('cannot upload when uploads are off', () async {
      s.uploads = false;
      final res = await s.send('POST', '/share/upload',
          query: {'name': 'x.txt'}, body: [1], token: token);
      expect(res.status, HttpStatus.forbidden);
      expect(s.names, isNot(contains('x.txt')));
    });

    test('an upload above the limit is refused by the bytes really sent', () async {
      final big = List.filled(2000, 65);
      final declared = await s.send('POST', '/share/upload',
          query: {'name': 'big.bin'}, body: big, token: token);
      expect(declared.status, HttpStatus.requestEntityTooLarge);
      final chunked = await s.send('POST', '/share/upload',
          query: {'name': 'big.bin'}, body: big, token: token, chunked: true);
      expect(chunked.status, isNot(HttpStatus.ok),
          reason: 'With no Content-Length the size check was skipped.');
      expect(s.names, ['salary.xlsx'], reason: 'nothing written, no temp left');
    });

    test('turning the folder off ends every access', () async {
      s.enabled = false;
      expect((await s.send('GET', '/share', token: token)).status, HttpStatus.notFound);
      s.enabled = true;
      expect((await s.send('GET', '/share', token: token)).status, HttpStatus.forbidden);
    });
  });

  group('ShareAccess', () {
    test('a token works only from the address it was given to', () {
      final access = ShareAccess();
      final token = access.admit('192.168.1.20', 'Phone', _fp);
      expect(access.check(token, '192.168.1.20', _fp)?.name, 'Phone');
      expect(access.check(token, '192.168.1.21', _fp), isNull);
    });

    test('a token unused for the idle limit expires', () {
      var now = DateTime(2026, 11, 3, 12);
      final access = ShareAccess(clock: () => now);
      final token = access.admit('10.0.0.2', 'Phone', _fp);
      now = now.add(ShareAccess.idleLimit - const Duration(seconds: 1));
      expect(access.check(token, '10.0.0.2', _fp), isNotNull);
      now = now.add(ShareAccess.idleLimit + const Duration(seconds: 1));
      expect(access.check(token, '10.0.0.2', _fp), isNull);
    });
  });

  test('a second access request while one waits is refused without asking', () async {
    s.answer = null;
    final first = s.askAccess();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await s.askAccess('Other'), isNull);
    expect(s.asked, hasLength(1));
    await first;
  });
}
