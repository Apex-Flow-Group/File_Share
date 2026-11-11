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
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../identity/tls_peer.dart';

typedef _Reply = ({int status, Object? body});

/// A device blocked while its file moves reads what its next offer reads:
/// a refusal, not the "cancelled" the receiving user's own cancel gives.
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
    await loadPeers();
  });

  setUp(() async {
    TransferProgressService().clearProgress();
    root = await Directory.systemTemp.createTemp('apex_block_reply_');
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

  Future<_Reply> read(HttpClientResponse res) async {
    final text = await res.transform(utf8.decoder).join();
    return (status: res.statusCode, body: jsonDecode(text));
  }

  Future<_Reply> offer(HttpClient client) async {
    final req = await client.postUrl(at(ApexProtocol.offerPath));
    req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
    req.write(jsonEncode({
      'id': 'phone',
      'name': 'Ali Phone',
      'files': [
        {'name': 'a.txt', 'size': 4},
        {'name': 'b.txt', 'size': 4},
      ],
    }));
    return read(await req.close());
  }

  Future<void> uploadStarted() async {
    final temp = Directory('${root.path}/tmp');
    for (var i = 0; i < 500 && temp.listSync().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(temp.listSync(), isNotEmpty, reason: 'the upload had begun');
  }

  test('a block mid-file answers the sender as the blocked offer is answered', () async {
    final client = phone.client(me);
    addTearDown(() => client.close(force: true));
    final accepted = await offer(client);
    final tokens = ((accepted.body as Map)['tokens'] as List).cast<String>();

    final up = await client.postUrl(at(ApexProtocol.uploadPath));
    up.headers
      ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
      ..set(ApexProtocol.tokenHeader, tokens[0]);
    up
      ..contentLength = 4
      ..bufferOutput = false
      ..add([1, 2]);
    await up.flush();
    await uploadStarted();
    blocks.block(chatPeer(phone.fingerprint, 'phone', '127.0.0.1'));
    up.add([3, 4]);
    final midFile = await read(await up.close());

    final nextOffer = await offer(client);

    expect(midFile.status, nextOffer.status);
    expect(midFile.body, nextOffer.body);
    expect(midFile.status, isNot(499), reason: 'a block is not the receiving user cancelling');
    expect(ApexProtocol.isRefusal(midFile.status, midFile.body), isTrue);
    expect(Directory('${root.path}/save').existsSync(), isFalse, reason: 'nothing is saved');
  });

  test('the sender reads that answer as refused, the way it reads a refused offer', () async {
    final folder = await Directory.systemTemp.createTemp('apex_block_reply_send_');
    final fake = await bindReceiver();
    addTearDown(() async {
      await fake.close(force: true);
      TransferProgressService().clearProgress();
      await folder.delete(recursive: true);
    });
    var refuseOffer = false;
    fake.listen((req) async {
      await req.drain<void>();
      final isOffer = req.uri.path == ApexProtocol.offerPath;
      req.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(isOffer && !refuseOffer
            ? {
                'accepted': true,
                'tokens': ['a']
              }
            : ApexProtocol.refusal));
      await req.response.close();
    });
    final file = File('${folder.path}/a.txt')..writeAsBytesSync([1, 2, 3, 4]);
    final target = Device(
        id: 't', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: fake.port, fingerprint: testReceiver.fingerprint);
    final send = SendHttp(getContext: senderContext, getLocalName: () => 'Test Phone', getLocalId: () => 'test-id');
    final files = [(path: file.path, name: 'a.txt', size: 4)];

    final blockedMidFile = await send.sendFiles(files, target);
    refuseOffer = true;
    final refusedOffer = await send.sendFiles(files, target);

    expect(blockedMidFile, refusedOffer);
    expect(blockedMidFile, SendOutcome.declined);
  });
}
