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
  late BlockList blocks;

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
    blocks = BlockList(pins);
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
        // Discovery heard the agreed phone announce a colleague's id too.
        'colleague' => phone.fingerprint,
        _ => null,
      },
      pins: pins,
      blocks: blocks,
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

  /// Offers one small file and, unless [upload] is false, sends it, so the
  /// batch is over before the next one.
  Future<bool> offer(TlsPeer from, String id, {bool upload = true}) async {
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
      final accepted = body['accepted'] == true;
      if (accepted && upload) {
        final up = await client.postUrl(Uri.https('127.0.0.1:${server.port}', ApexProtocol.uploadPath));
        up.headers
          ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
          ..set(ApexProtocol.tokenHeader, (body['tokens'] as List).first as String);
        up
          ..contentLength = 3
          ..add([1, 2, 3]);
        await (await up.close()).drain<void>();
      }
      TransferProgressService().clearProgress();
      return accepted;
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

  test('an agreed device taking a colleague\'s unpinned id is asked, not let in', () async {
    await offer(phone, 'phone');
    await offer(phone, 'colleague');
    expect(asked, ['phone', 'colleague'],
        reason: 'unasked, its key would be pinned for the colleague and the colleague turned away');
  });

  test('every block forgets it: unblocking the id with another key lets the old key in unasked no more',
      () async {
    await offer(phone, 'phone');
    // Blocked by the chat (its question refused, say), not by the card.
    blocks.block(chatPeer(phone.fingerprint, 'phone', '127.0.0.1'));
    // The same id back with another key is unblocked: that lifts the old block too.
    blocks.unblock(chatPeer(other.fingerprint, 'phone', '127.0.0.1'));
    expect(blocks.isBlocked(chatPeer(phone.fingerprint, 'phone', '127.0.0.1')), isFalse);
    await offer(phone, 'phone');
    expect(asked, ['phone', 'phone']);
  });

  test('one batch at a time unasked: another while it is open is asked about', () async {
    await offer(phone, 'phone', upload: false);
    await offer(phone, 'phone', upload: false);
    expect(asked, ['phone', 'phone'], reason: 'a device must not open batches without end');
  });
}
