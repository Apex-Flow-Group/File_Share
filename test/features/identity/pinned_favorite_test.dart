@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_door.dart';
import 'tls_peer.dart';

/// Owner decision: a favorite that discovery has not heard this run is sent
/// to with the fingerprint pinned when it was last accepted. Real TLS on
/// 127.0.0.1: the favorite is the server, this device the sender.
void main() {
  late TlsPeer office;
  late TlsPeer phone;
  late TlsPeer other;

  setUpAll(() async {
    office = await TlsPeer.create();
    phone = await TlsPeer.create();
    other = await TlsPeer.create();
  });

  SendHttp sender() =>
      SendHttp(getLocalName: () => 'Ali Phone', getLocalId: () => 'phone', getContext: phone.identity.clientContext);

  /// The office PC as the favorites list keeps it: no certificate, since
  /// the list is saved without one.
  Device favorite(int port) =>
      Device.fromJson(jsonDecode(jsonEncode(office.device(port, id: 'office-pc').toJson())) as Map<String, dynamic>);

  group('a chat message', () {
    late ChatDoor door;
    setUp(() async {
      door = await ChatDoor.start(office, [phone])
        ..hear(phone, 'phone');
    });
    tearDown(() => door.stop());

    test('reaches a favorite not discovered, by the fingerprint pinned at its last acceptance', () async {
      final pins = PinStore.memory();
      await pins.pin('office-pc', office.fingerprint);
      final target = pins.withPin(favorite(door.port));
      expect(target.fingerprint, office.fingerprint);
      final r = await sender().sendChat('hello', target, null);
      expect(r.outcome, ChatOutcome.sent);
      expect(door.delivered.single.text, 'hello');
    });

    test('with no pin it fails as before, and nothing reaches the favorite', () async {
      final target = PinStore.memory().withPin(favorite(door.port));
      expect(target.fingerprint, isEmpty);
      final r = await sender().sendChat('hello', target, null);
      expect(r.outcome, ChatOutcome.failed);
      expect(door.asked, isEmpty);
    });

    test('a pin of another certificate reaches nobody: the sender refuses the server', () async {
      final pins = PinStore.memory();
      await pins.pin('office-pc', other.fingerprint);
      final r = await sender().sendChat('my password', pins.withPin(favorite(door.port)), null);
      expect(r.outcome, ChatOutcome.failed);
      expect(door.asked, isEmpty);
    });

    test('what is written to the favorite is in the same chat as when it is discovered', () async {
      final pins = PinStore.memory();
      await pins.pin('office-pc', office.fingerprint);
      final store = ChatStore(send: sender().sendChat);
      await store.write(pins.withPin(favorite(door.port)), 'while away');
      await store.write(office.device(door.port, id: 'office-pc'), 'now heard');
      expect(store.thread(ChatKey(office.fingerprint))!.messages.map((m) => m.text), ['while away', 'now heard']);
      expect(store.thread(ChatKey(office.fingerprint))!.messages.map((m) => m.status), [ChatStatus.sent, ChatStatus.sent]);
    });
  });

  test('a fingerprint discovery heard is kept over the pin', () async {
    final pins = PinStore.memory();
    await pins.pin('office-pc', other.fingerprint);
    final heard = office.device(1, id: 'office-pc');
    expect(pins.withPin(heard).fingerprint, office.fingerprint);
  });

  group('files', () {
    late Directory root;
    late HttpServer server;
    late List<ConnectionRequest> asked;

    setUp(() async {
      TransferProgressService().clearProgress();
      root = await Directory.systemTemp.createTemp('apex_pinned_favorite_');
      Directory('${root.path}/tmp').createSync();
      asked = [];
      final receive = ReceiveHttp(
        expectedFingerprint: (id, address) => id == 'phone' ? phone.fingerprint : null,
        pins: PinStore.memory(),
        gate: ReceiveGate(),
        store: ReceiveStore(
          tempFolder: () async => Directory('${root.path}/tmp'),
          place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
        ),
        onConnectionRequest: (r) {
          asked.add(r);
          r.onResponse(true);
        },
        onFileReceived: (_) {},
      );
      server = await office.bind([phone]);
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

    test('reach a favorite not discovered by its pinned fingerprint, and fail without one', () async {
      final file = File('${root.path}/a.txt')..writeAsStringSync('abc');
      final files = [(path: file.path, name: 'a.txt', size: 3)];
      final none = await sender().sendFiles(files, PinStore.memory().withPin(favorite(server.port)));
      expect(none, SendOutcome.failed);
      expect(asked, isEmpty);

      final pins = PinStore.memory();
      await pins.pin('office-pc', office.fingerprint);
      final sent = await sender().sendFiles(files, pins.withPin(favorite(server.port)));
      expect(sent, SendOutcome.sent);
      expect(asked.single.device.id, 'phone');
    });
  });
}
