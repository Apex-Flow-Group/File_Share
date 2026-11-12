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

/// Files are asked about once per device until the app closes (owner
/// decision), at the certificate the user agreed to. Real TLS on 127.0.0.1.
void main() {
  late TlsPeer me;
  late TlsPeer phone;
  late TlsPeer other;
  late Directory root;
  late HttpServer server;
  late ReceiveHttp receive;
  late List<String> asked;
  late bool answer;

  setUpAll(() async {
    me = await TlsPeer.create();
    phone = await TlsPeer.create();
    other = await TlsPeer.create();
  });

  setUp(() async {
    TransferProgressService().clearProgress();
    asked = [];
    answer = true;
    root = await Directory.systemTemp.createTemp('apex_files_once_');
    Directory('${root.path}/tmp').createSync();
    final pins = PinStore.memory();
    receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => Directory('${root.path}/tmp'),
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
      ),
      onConnectionRequest: (r) {
        asked.add(r.device.id);
        r.onResponse(answer);
      },
      onFileReceived: (_) {},
      expectedFingerprint: (id, address) => switch (id) {
        'phone' => phone.fingerprint,
        'other' => other.fingerprint,
        _ => null,
      },
      pins: pins,
      blocks: BlockList(pins),
    );
    server = await me.bind([phone, other]);
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

  Future<bool> offer(TlsPeer from, String id) async {
    final client = from.client(me);
    try {
      final req = await client.postUrl(Uri.https('127.0.0.1:${server.port}', ApexProtocol.offerPath));
      req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
      req.write(jsonEncode({
        'id': id,
        'name': id,
        'files': [
          {'name': 'note.txt', 'size': 3},
        ],
      }));
      final body = jsonDecode(await (await req.close()).transform(utf8.decoder).join()) as Map;
      TransferProgressService().clearProgress();
      return body['accepted'] == true;
    } finally {
      client.close(force: true);
    }
  }

  test('the first batch asks; the next batches of that device come in unasked', () async {
    expect(await offer(phone, 'phone'), isTrue);
    expect(await offer(phone, 'phone'), isTrue);
    expect(await offer(phone, 'phone'), isTrue);
    expect(asked, ['phone']);
  });

  test('another device is still asked', () async {
    await offer(phone, 'phone');
    await offer(other, 'other');
    expect(asked, ['phone', 'other']);
  });

  test('a refused batch agrees to nothing: the next one asks again', () async {
    answer = false;
    expect(await offer(phone, 'phone'), isFalse);
    answer = true;
    expect(await offer(phone, 'phone'), isTrue);
    expect(asked, ['phone', 'phone']);
  });

  test('after a block, or its end, the device is asked again', () async {
    await offer(phone, 'phone');
    receive.forgetFiles(chatPeer(phone.fingerprint, 'phone', '127.0.0.1'));
    await offer(phone, 'phone');
    expect(asked, ['phone', 'phone']);
  });
}
