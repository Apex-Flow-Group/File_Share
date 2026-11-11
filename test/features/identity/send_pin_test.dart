@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/features/chat/ui/chat_outcome_message.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/features/send/ui/send_outcome_message.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_door.dart';
import 'tls_peer.dart';

/// A favorite this device only ever sent to: when it accepts, the
/// fingerprint it showed in the TLS handshake is pinned, so it is reached
/// later while not discovered. A pin is never written over, and a device
/// showing another key than the pinned one is not sent to. Real TLS on
/// 127.0.0.1: the favorite is the server, this device the sender.
void main() {
  late TlsPeer office;
  late TlsPeer phone;
  late TlsPeer other;
  late PinStore pins;

  setUpAll(() async {
    office = await TlsPeer.create();
    phone = await TlsPeer.create();
    other = await TlsPeer.create();
  });

  setUp(() => pins = PinStore.memory());

  SendHttp sender() => SendHttp(
      getLocalName: () => 'Ali Phone',
      getLocalId: () => 'phone',
      getContext: phone.identity.clientContext,
      pins: pins);

  /// The office PC as the favorites list keeps it: no certificate.
  Device favorite(int port) =>
      Device.fromJson(jsonDecode(jsonEncode(office.device(port, id: 'office-pc').toJson())) as Map<String, dynamic>);

  group('a chat message', () {
    late ChatDoor door;
    setUp(() async {
      door = await ChatDoor.start(office, [phone])
        ..hear(phone, 'phone');
    });
    tearDown(() => door.stop());

    test('accepted by a device never pinned pins the key it showed, and reaches it later undiscovered',
        () async {
      final r = await sender().sendChat('hello', office.device(door.port, id: 'office-pc'), null);
      expect(r.outcome, ChatOutcome.sent);
      expect(pins.pinned('office-pc'), office.fingerprint);

      final away = pins.withPin(favorite(door.port));
      expect(away.fingerprint, office.fingerprint);
      expect((await sender().sendChat('while away', away, null)).outcome, ChatOutcome.sent);
      expect(door.delivered.map((m) => m.text), ['hello', 'while away']);
    });

    test('refused, it pins nothing', () async {
      door.decide = (_) => false;
      final r = await sender().sendChat('hello', office.device(door.port, id: 'office-pc'), null);
      expect(r.outcome, ChatOutcome.declined);
      expect(pins.pinned('office-pc'), isNull);
    });

    test('a device with another key than the pinned one gets nothing, and the pin stays', () async {
      await pins.pin('office-pc', other.fingerprint);
      final r = await sender().sendChat('my password', office.device(door.port, id: 'office-pc'), null);
      expect(r.outcome, ChatOutcome.keyChanged);
      expect(door.asked, isEmpty, reason: 'nothing left this device');
      expect(pins.pinned('office-pc'), other.fingerprint);
    });
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('the sender reads that nothing went, not the warning of the request dialog (${locale.languageCode})',
        () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(chatOutcomeMessage(l10n, ChatOutcome.keyChanged), l10n.sendNewKey);
      expect(sendOutcomeMessage(l10n, SendOutcome.keyChanged, sent: '', failed: ''), l10n.sendNewKey);
      expect(l10n.sendNewKey, isNot(l10n.requestNewKey));
    });
  }

  group('files', () {
    late Directory root;
    late HttpServer server;
    late List<ConnectionRequest> asked;

    setUp(() async {
      TransferProgressService().clearProgress();
      root = await Directory.systemTemp.createTemp('apex_send_pin_');
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

    List<OutgoingFile> oneFile() {
      final file = File('${root.path}/a.txt')..writeAsStringSync('abc');
      return [(path: file.path, name: 'a.txt', size: 3)];
    }

    test('an accepted offer pins the key the favorite showed, and later files reach it undiscovered', () async {
      expect(await sender().sendFiles(oneFile(), office.device(server.port, id: 'office-pc')), SendOutcome.sent);
      expect(pins.pinned('office-pc'), office.fingerprint);
      expect(await sender().sendFiles(oneFile(), pins.withPin(favorite(server.port))), SendOutcome.sent);
      expect(asked, hasLength(2));
    });

    test('a device with another key than the pinned one is offered nothing, and the pin stays', () async {
      await pins.pin('office-pc', other.fingerprint);
      expect(await sender().sendFiles(oneFile(), office.device(server.port, id: 'office-pc')),
          SendOutcome.keyChanged);
      expect(asked, isEmpty);
      expect(pins.pinned('office-pc'), other.fingerprint);
    });
  });
}
