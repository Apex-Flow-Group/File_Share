import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real server on 127.0.0.1 runs the real receive code. The save and temp
/// folders are passed in, so no test touches the user's files on any system.
void main() {
  late Directory root;
  late Directory saveDir;
  late Directory tempDir;
  late HttpServer server;
  /// true accepts, false refuses, null never answers.
  late bool? Function(ConnectionRequest) decide;
  late int? freeBytes;
  final shown = <ConnectionRequest>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('apex_receive_http_');
    saveDir = Directory('${root.path}/save');
    tempDir = Directory('${root.path}/tmp')..createSync();
    decide = (_) => true;
    freeBytes = null;
    shown.clear();
    TransferProgressService().clearProgress();

    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => tempDir,
        place: (temp, name) async => (await moveIntoFolder(temp, saveDir, name)).path,
      ),
      onConnectionRequest: (r) {
        shown.add(r);
        final answer = decide(r);
        if (answer != null) {
          r.onResponse(answer);
        }
      },
      onFileReceived: (_) {},
      freeBytes: () async => freeBytes,
      decisionTimeout: const Duration(milliseconds: 300),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (!await receive.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    TransferProgressService().clearProgress();
    await root.delete(recursive: true);
  });

  Future<({int status, Map<String, dynamic> body})> call(
    String path, {
    String method = 'POST',
    String? version = '${ApexProtocol.version}',
    String? token,
    List<int>? body,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.http('127.0.0.1:${server.port}', path));
      if (version != null) {
        req.headers.set(ApexProtocol.versionHeader, version);
      }
      if (token != null) {
        req.headers.set(ApexProtocol.tokenHeader, token);
      }
      if (body != null) {
        req.contentLength = body.length;
        req.add(body);
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      return (status: res.statusCode, body: text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  List<int> offerBody(Map<String, int> files, {String name = 'Linux PC', Map<String, Object>? extra}) =>
      utf8.encode(jsonEncode({
        'id': 'test-phone',
        'name': name,
        'files': [for (final e in files.entries) {'name': e.key, 'size': e.value}],
        ...?extra,
      }));

  Future<List<String>> accepted(Map<String, int> files) async {
    final r = await call(ApexProtocol.offerPath, body: offerBody(files));
    expect(r.status, HttpStatus.ok);
    expect(r.body['accepted'], isTrue);
    return (r.body['tokens'] as List).cast<String>();
  }

  Future<int> upload(String? token, List<int> bytes, {String? version = '${ApexProtocol.version}'}) async =>
      (await call(ApexProtocol.uploadPath, token: token, body: bytes, version: version)).status;

  List<File> saved() =>
      saveDir.existsSync() ? saveDir.listSync(recursive: true).whereType<File>().toList() : <File>[];

  List<String> tempLeft() => tempDir.listSync().map((e) => e.uri.pathSegments.last).toList();

  group('version: every request carries the current protocol number', () {
    test('a request with no version is refused with "update required"', () async {
      for (final path in [ApexProtocol.offerPath, ApexProtocol.uploadPath]) {
        final r = await call(path, version: null, body: offerBody({'a.txt': 1}));
        expect(r.status, HttpStatus.upgradeRequired, reason: path);
        expect(r.body['error'], ApexProtocol.updateRequired);
      }
      final ping = await call(ApexProtocol.pingPath, method: 'GET', version: null);
      expect(ping.status, HttpStatus.upgradeRequired);
      expect(shown, isEmpty, reason: 'An old sender must not reach the accept dialog.');
    });

    test('an older or newer version is refused the same way', () async {
      for (final v in ['${ApexProtocol.version - 1}', '${ApexProtocol.version + 1}', 'abc']) {
        final r = await call(ApexProtocol.offerPath, version: v, body: offerBody({'a.txt': 1}));
        expect(r.status, HttpStatus.upgradeRequired, reason: v);
      }
      expect(shown, isEmpty);
    });

    test('an accepted upload sent without the version writes nothing', () async {
      final token = (await accepted({'a.txt': 5})).single;
      expect(await upload(token, utf8.encode('hello'), version: null), HttpStatus.upgradeRequired);
      expect(saved(), isEmpty);
    });

    test('ping answers with the version', () async {
      final r = await call(ApexProtocol.pingPath, method: 'GET');
      expect(r.status, HttpStatus.ok);
      expect(r.body['version'], ApexProtocol.version);
    });
  });

  group('token: nothing is written without an accepted offer', () {
    test('an upload with no token is refused and nothing is saved', () async {
      expect(await upload(null, utf8.encode('hello')), HttpStatus.forbidden);
      expect(saved(), isEmpty);
      expect(tempLeft(), isEmpty);
    });

    test('after the user refused, there is no token and an upload is refused', () async {
      decide = (_) => false;
      final r = await call(ApexProtocol.offerPath, body: offerBody({'a.txt': 5}));
      expect(r.body['accepted'], isFalse);
      expect(r.body['tokens'], isNull);
      expect(await upload('made-up', utf8.encode('hello')), HttpStatus.forbidden);
      expect(saved(), isEmpty);
    });

    test('an offer nobody answers is refused when the wait ends', () async {
      decide = (_) => null;
      final r = await call(ApexProtocol.offerPath, body: offerBody({'a.txt': 5}));
      expect(shown, hasLength(1));
      expect(r.body['accepted'], isFalse);
    });

    test('an accepted file arrives with its content', () async {
      final token = (await accepted({'note.txt': 5})).single;
      expect(await upload(token, utf8.encode('hello')), HttpStatus.ok);
      expect(saved().single.readAsStringSync(), 'hello');
      expect(saved().single.uri.pathSegments.last, 'note.txt');
    });

    test('a token is used once: the second upload is refused', () async {
      final token = (await accepted({'note.txt': 5})).single;
      await upload(token, utf8.encode('hello'));
      expect(await upload(token, utf8.encode('again')), HttpStatus.forbidden);
      expect(saved(), hasLength(1));
    });

    test('a body bigger or smaller than the accepted size is refused', () async {
      final tokens = await accepted({'a.txt': 5, 'b.txt': 5});
      expect(await upload(tokens[0], utf8.encode('hello, much longer')), isNot(HttpStatus.ok));
      expect(await upload(tokens[1], utf8.encode('hi')), isNot(HttpStatus.ok));
      expect(saved(), isEmpty);
      expect(tempLeft(), isEmpty);
    });
  });

  group('the batch is refused whole, before the user is asked', () {
    test('more files than the limit', () async {
      final many = {for (var i = 0; i <= TransferRules.maxFilesPerBatch; i++) 'f$i.txt': 1};
      final r = await call(ApexProtocol.offerPath, body: offerBody(many));
      expect(r.status, isNot(HttpStatus.ok));
      expect(r.body['error'], 'tooManyFiles');
      expect(shown, isEmpty);
    });

    test('more bytes than the free space', () async {
      freeBytes = 9;
      final r = await call(ApexProtocol.offerPath, body: offerBody({'a.txt': 5, 'b.txt': 5}));
      expect(r.body['error'], 'notEnoughSpace');
      expect(shown, isEmpty);
    });

    test('a body that is not an offer', () async {
      final r = await call(ApexProtocol.offerPath, body: utf8.encode('not json'));
      expect(r.status, HttpStatus.badRequest);
      expect(shown, isEmpty);
    });
  });

  group('who sent it', () {
    test('the accept dialog shows the real sender address, not one it claims', () async {
      decide = (_) => false;
      await call(ApexProtocol.offerPath,
          body: offerBody({'a.txt': 1}, name: 'Manager PC', extra: {'ip': '10.0.0.5', 'address': '10.0.0.5'}));
      expect(shown.single.device.ip, '127.0.0.1');
      expect(shown.single.device.name, 'Manager PC');
    });
  });

  group('names and files on disk', () {
    test('a second file with the same name keeps the first one', () async {
      await upload((await accepted({'report.txt': 5})).single, utf8.encode('first'));
      await upload((await accepted({'report.txt': 6})).single, utf8.encode('second'));
      expect(saved().map((f) => f.readAsStringSync()).toSet(), {'first', 'second'});
    });

    test('a name that is valid on Linux arrives on Windows, with no stray file', () async {
      final token = (await accepted({'notes: draft?.txt': 5})).single;
      expect(await upload(token, utf8.encode('hello')), HttpStatus.ok);
      expect(saved().single.uri.pathSegments.last, 'notes_ draft_.txt');
      expect(tempLeft(), isEmpty);
    });

    test('a name that climbs out of the folder stays inside it', () async {
      final token = (await accepted({'../../escape.txt': 5})).single;
      await upload(token, utf8.encode('hello'));
      String norm(String p) => p.replaceAll(r'\', '/').toLowerCase();
      final outside = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => !norm(f.path).startsWith(norm(saveDir.path)));
      expect(outside, isEmpty);
      expect(saved(), hasLength(1));
    });

    test('a sender that disconnects mid-file leaves no partial file', () async {
      final token = (await accepted({'big.bin': 1000})).single;
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      socket.write('POST ${ApexProtocol.uploadPath} HTTP/1.1\r\n'
          'Host: 127.0.0.1\r\n'
          '${ApexProtocol.versionHeader}: ${ApexProtocol.version}\r\n'
          '${ApexProtocol.tokenHeader}: $token\r\n'
          'Content-Length: 1000\r\n\r\n');
      socket.add(List<int>.filled(100, 7));
      await socket.flush();
      // Wait until the receiver has opened its temp file, so the test proves
      // the cleanup and not a request that never arrived.
      final opened = DateTime.now().add(const Duration(seconds: 5));
      while (tempLeft().isEmpty && DateTime.now().isBefore(opened)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(tempLeft(), isNotEmpty, reason: 'The upload never started.');
      await socket.close();
      socket.destroy();

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (tempLeft().isNotEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(saved(), isEmpty);
      expect(tempLeft(), isEmpty, reason: 'A half file stays in the temp folder.');
    });
  });
}
