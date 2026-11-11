@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/features/chat/logic/block_list.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

/// The shared folder asks the chat's block list on every route, after the
/// identity check, and a block ends the tokens the device holds, so what it
/// is downloading or uploading stops and leaves nothing behind. Real TLS on
/// 127.0.0.1 with the real handler.
void main() {
  setUpAll(loadPeers);
  late Directory dir;
  late HttpServer server;
  late PinStore pins;
  late BlockList blocks;
  late List<ConnectionRequest> asked;

  ChatPeer phone() => chatPeer(testSender.fingerprint, 'phone', '127.0.0.1');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('apex_share_block_');
    File('${dir.path}/salary.xlsx').writeAsStringSync('private');
    pins = PinStore.memory();
    blocks = BlockList(pins);
    asked = [];
    final share = ShareFolderHttp(
      expectedFingerprint: await heardSender(),
      pins: pins,
      blocks: blocks,
      isEnabled: () => true,
      allowUploads: () => true,
      getLocalName: () => 'Office PC',
      service: _TempShareService(dir.path),
      onAccessRequest: (r) {
        asked.add(r);
        r.onResponse(true);
      },
      decisionTimeout: const Duration(milliseconds: 200),
      maxUploadBytes: 64 * 1024 * 1024,
    );
    server = await bindReceiver();
    server.listen((req) async {
      if (!await share.handle(req)) {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  List<String> names() => dir.listSync().map((f) => f.uri.pathSegments.last).toList();

  Future<HttpClientRequest> open(HttpClient client, String method, String path,
      {Map<String, String>? query, String? token}) async {
    final req = await client.openUrl(method, Uri.https('127.0.0.1:${server.port}', path, query));
    req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
    if (token != null) {
      req.headers.set(ApexProtocol.tokenHeader, token);
    }
    return req;
  }

  Future<({int status, String body})> send(String method, String path,
      {Map<String, String>? query, List<int>? body, String? token}) async {
    final client = await senderClient();
    try {
      final req = await open(client, method, path, query: query, token: token);
      if (body != null) {
        req.contentLength = body.length;
        req.add(body);
      }
      final res = await req.close();
      return (status: res.statusCode, body: await res.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }

  Future<({int status, Object? json})> askAccess() async {
    final res = await send('POST', ShareFolderHttp.accessPath,
        body: utf8.encode(jsonEncode({'id': 'phone', 'name': 'Ali Phone'})));
    return (status: res.status, json: jsonDecode(res.body));
  }

  Future<String> admitted() async {
    final token = ((await askAccess()).json as Map)['token'] as String;
    // An accepted request must work first, or a refusal below proves nothing.
    expect((await send('GET', ShareFolderHttp.listPath, token: token)).status, HttpStatus.ok);
    return token;
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 250 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  group('a blocked device', () {
    test('asking for the folder, is not asked about, and reads a refusal', () async {
      blocks.block(phone());
      final res = await askAccess();
      expect(res.status, HttpStatus.ok);
      expect(res.json, {'accepted': false, 'reason': 'refused'});
      expect(asked, isEmpty);
    });

    test('with a token from before the block, opens no route and writes nothing', () async {
      final token = await admitted();
      blocks.block(phone());

      for (final path in [ShareFolderHttp.listPath, '/share/info']) {
        expect((await send('GET', path, token: token)).status, HttpStatus.forbidden, reason: path);
      }
      final down = await send('GET', ShareFolderHttp.filePath, query: {'name': 'salary.xlsx'}, token: token);
      expect(down.status, HttpStatus.forbidden);
      expect(down.body, isNot(contains('private')));
      final up = await send('POST', ShareFolderHttp.uploadPath,
          query: {'name': 'x.txt'}, body: utf8.encode('x'), token: token);
      expect(up.status, HttpStatus.forbidden);
      expect(names(), ['salary.xlsx']);
    });

    test('by the same rule: a block on the pinned id with another key leaves the pinned device in', () async {
      final token = await admitted();
      expect(pins.pinned('phone'), testSender.fingerprint);
      blocks.block(chatPeer(testReceiver.fingerprint, 'phone', '127.0.0.2'));
      expect((await send('GET', ShareFolderHttp.listPath, token: token)).status, HttpStatus.ok);
    });
  });

  group('a block during a transfer', () {
    test('stops a download: the device never gets the whole file', () async {
      const size = 32 * 1024 * 1024;
      final big = File('${dir.path}/big.bin');
      final sink = big.openWrite();
      final block = List.filled(1024 * 1024, 7);
      for (var i = 0; i < size ~/ block.length; i++) {
        sink.add(block);
      }
      await sink.close();
      final token = await admitted();

      final client = await senderClient();
      var received = 0;
      try {
        final req = await open(client, 'GET', ShareFolderHttp.filePath, query: {'name': 'big.bin'}, token: token);
        final res = await req.close();
        expect(res.statusCode, HttpStatus.ok);
        final body = StreamIterator(res);
        expect(await body.moveNext(), isTrue);
        received += body.current.length;
        blocks.block(phone());
        try {
          while (await body.moveNext().timeout(const Duration(seconds: 10))) {
            received += body.current.length;
          }
        } on Object {
          // The connection ended before the whole file: what is expected.
        }
      } finally {
        client.close(force: true);
      }
      expect(received, lessThan(size));
    });

    test('stops an upload, and its half-written file is deleted', () async {
      const size = 2 * 1024 * 1024;
      final token = await admitted();
      final client = await senderClient();
      int? status;
      try {
        final req = await open(client, 'POST', ShareFolderHttp.uploadPath, query: {'name': 'big.bin'}, token: token);
        req
          ..contentLength = size
          ..bufferOutput = false
          ..add(List.filled(size ~/ 2, 1));
        await req.flush();
        await until(() => names().any((n) => n.endsWith('.apex_tmp')));
        expect(names().any((n) => n.endsWith('.apex_tmp')), isTrue, reason: 'the upload had begun');
        blocks.block(phone());
        req.add(List.filled(size ~/ 2, 1));
        status = (await req.close().timeout(const Duration(seconds: 10))).statusCode;
      } on Object {
        // The server ended the connection: also a refusal.
      } finally {
        client.close(force: true);
      }
      expect(status, anyOf(isNull, HttpStatus.forbidden));
      await until(() => names().length == 1);
      expect(names(), ['salary.xlsx'], reason: 'no file and no temp file is left');
    });
  });
}
