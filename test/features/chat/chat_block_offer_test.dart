@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/chat/data/chat_http.dart';
import 'package:apex_file_share/features/chat/logic/block_list.dart';
import 'package:apex_file_share/features/chat/logic/chat_access.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';

/// A blocked device offers no files either: the file door asks the same
/// block list as the chat, and turns it away before its user is asked, with
/// the answer a blocked device gets in the chat. Real TLS on 127.0.0.1.
void main() {
  late TlsPeer me;
  late TlsPeer phone;
  late TlsPeer impostor;
  late Directory root;
  late HttpServer server;
  late PinStore pins;
  late BlockList blocks;
  late List<ConnectionRequest> asked;

  setUpAll(() async {
    me = await TlsPeer.create();
    phone = await TlsPeer.create();
    impostor = await TlsPeer.create();
  });

  setUp(() async {
    TransferProgressService().clearProgress();
    root = await Directory.systemTemp.createTemp('apex_block_offer_');
    Directory('${root.path}/tmp').createSync();
    pins = PinStore.memory();
    blocks = BlockList(pins);
    asked = [];
    void ask(ConnectionRequest r) {
      asked.add(r);
      r.onResponse(true);
    }

    String? heard(String id, String address) => id == 'phone' ? phone.fingerprint : null;
    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => Directory('${root.path}/tmp'),
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
      ),
      onConnectionRequest: ask,
      onFileReceived: (_) {},
      expectedFingerprint: heard,
      pins: pins,
      blocks: blocks,
    );
    final chat = ChatHttp(
      onRequest: ask,
      onMessage: (_) {},
      expectedFingerprint: heard,
      pins: pins,
      access: ChatAccess(blocks: blocks),
    );
    server = await me.bind([phone, impostor]);
    server.listen((req) async {
      if (!await receive.handle(req) && !await chat.handle(req)) {
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

  SendHttp sender() =>
      SendHttp(getLocalName: () => 'Ali Phone', getLocalId: () => 'phone', getContext: phone.identity.clientContext);

  Future<({int status, Object? json})> post(String path, Object body) async {
    final client = phone.client(me);
    try {
      final req = await client.postUrl(Uri.https('127.0.0.1:${server.port}', path));
      req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
      req.write(jsonEncode(body));
      final res = await req.close();
      return (status: res.statusCode, json: jsonDecode(await res.transform(utf8.decoder).join()));
    } finally {
      client.close(force: true);
    }
  }

  List<OutgoingFile> oneFile() {
    final file = File('${root.path}/a.txt')..writeAsStringSync('abc');
    return [(path: file.path, name: 'a.txt', size: 3)];
  }

  test('a blocked device\'s offer is turned away unasked, with the answer the chat gives it', () async {
    blocks.block(chatPeer(phone.fingerprint, 'phone', '127.0.0.1'));

    final offer = await post(ApexProtocol.offerPath, {
      'id': 'phone',
      'name': 'Ali Phone',
      'files': [
        {'name': 'a.txt', 'size': 3},
      ],
    });
    final chat = await post(ApexProtocol.chatPath, {'id': 'phone', 'name': 'Ali Phone', 'text': 'hi'});
    expect(offer.status, HttpStatus.ok);
    expect(offer.status, chat.status);
    expect(offer.json, chat.json);
    expect(offer.json, {'accepted': false});

    expect(await sender().sendFiles(oneFile(), me.device(server.port)), SendOutcome.declined);
    expect(asked, isEmpty, reason: 'its user is never asked');
    expect(Directory('${root.path}/save').existsSync(), isFalse, reason: 'not a byte written');
  });

  test('by the same rule: a block on the pinned phone\'s id with another key lets its offer through', () async {
    await pins.pin('phone', phone.fingerprint);
    blocks.block(chatPeer(impostor.fingerprint, 'phone', '127.0.0.2'));

    expect(await sender().sendFiles(oneFile(), me.device(server.port)), SendOutcome.sent);
    expect(asked, hasLength(1));
  });
}
