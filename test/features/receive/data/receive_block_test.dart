@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/chat/logic/block_list.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../identity/tls_peer.dart';

/// Blocking a device while its batch is arriving ends every upload token it
/// was given: the file moving now stops, its temp file is deleted, nothing
/// reaches the save folder, and the next file of the batch is refused.
/// Real TLS on 127.0.0.1.
void main() {
  late TlsPeer me;
  late TlsPeer phone;
  late Directory root;
  late HttpServer server;
  late BlockList blocks;

  setUpAll(() async {
    me = await TlsPeer.create();
    phone = await TlsPeer.create();
  });

  setUp(() async {
    TransferProgressService().clearProgress();
    root = await Directory.systemTemp.createTemp('apex_receive_block_');
    Directory('${root.path}/tmp').createSync();
    final pins = PinStore.memory();
    blocks = BlockList(pins);
    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => Directory('${root.path}/tmp'),
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
      ),
      onConnectionRequest: (r) => r.onResponse(true),
      onFileReceived: (_) {},
      expectedFingerprint: (id, address) => id == 'phone' ? phone.fingerprint : null,
      pins: pins,
      blocks: blocks,
    );
    server = await me.bind([phone]);
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

  Uri at(String path) => Uri.https('127.0.0.1:${server.port}', path);

  List<FileSystemEntity> temps() => Directory('${root.path}/tmp').listSync();
  List<FileSystemEntity> saved() {
    final save = Directory('${root.path}/save');
    return save.existsSync() ? save.listSync() : [];
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 250 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('a block mid-file stops it, deletes its temp file, and refuses the rest of the batch', () async {
    const size = 2 * 1024 * 1024;
    final client = phone.client(me);
    try {
      final offer = await client.postUrl(at(ApexProtocol.offerPath));
      offer.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
      offer.write(jsonEncode({
        'id': 'phone',
        'name': 'Ali Phone',
        'files': [
          {'name': 'big.bin', 'size': size},
          {'name': 'small.txt', 'size': 3},
        ],
      }));
      final answer = jsonDecode(await (await offer.close()).transform(utf8.decoder).join()) as Map;
      final tokens = (answer['tokens'] as List).cast<String>();

      int? status;
      try {
        final up = await client.postUrl(at(ApexProtocol.uploadPath));
        up.headers
          ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
          ..set(ApexProtocol.tokenHeader, tokens[0]);
        up
          ..contentLength = size
          ..bufferOutput = false
          ..add(List.filled(size ~/ 2, 1));
        await up.flush();
        await until(() => temps().isNotEmpty);
        expect(temps(), isNotEmpty, reason: 'the upload had begun');
        blocks.block(chatPeer(phone.fingerprint, 'phone', '127.0.0.1'));
        up.add(List.filled(size ~/ 2, 1));
        status = (await up.close().timeout(const Duration(seconds: 10))).statusCode;
      } on Object {
        // The server ended the connection: also a refusal.
      }
      expect(status, isNot(HttpStatus.ok));
      await until(() => temps().isEmpty);
      expect(temps(), isEmpty, reason: 'no temp file is left');
      expect(saved(), isEmpty, reason: 'nothing reaches the save folder');

      final next = await client.postUrl(at(ApexProtocol.uploadPath));
      next.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..set(ApexProtocol.tokenHeader, tokens[1]);
      next
        ..contentLength = 3
        ..add(utf8.encode('abc'));
      final res = await next.close();
      await res.drain<void>();
      expect(res.statusCode, HttpStatus.forbidden, reason: 'the rest of the batch is refused');
      expect(saved(), isEmpty);
    } finally {
      client.close(force: true);
    }
  });
}
