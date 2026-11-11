@TestOn('vm')
library;

import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tls_peer.dart';

/// The way out of "not sent: the other device has a new key": the user sends
/// from the other device to this one and accepts the question, which warns
/// of the new key. That one acceptance writes the new key over the pin (owner
/// decision: no second confirmation), and sending works again. The message
/// says so, naming the button the question shows. Real TLS on 127.0.0.1.
void main() {
  late TlsPeer phone;
  late TlsPeer office;
  late TlsPeer oldOffice;
  late Directory root;

  setUpAll(() async {
    phone = await TlsPeer.create();
    office = await TlsPeer.create();
    oldOffice = await TlsPeer.create();
  });

  setUp(() async {
    TransferProgressService().clearProgress();
    root = await Directory.systemTemp.createTemp('apex_new_key_');
  });

  tearDown(() async {
    TransferProgressService().clearProgress();
    await root.delete(recursive: true);
  });

  /// [me]'s receiving door, which hears [from] as [fromId].
  Future<HttpServer> door(TlsPeer me, TlsPeer from, String fromId, PinStore pins, List<ConnectionRequest> asked) async {
    final folder = Directory('${root.path}/${me.fingerprint.substring(0, 8)}')..createSync();
    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => folder,
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${folder.path}/save'), name)).path,
      ),
      onConnectionRequest: (r) {
        asked.add(r);
        r.onResponse(true);
      },
      onFileReceived: (_) {},
      expectedFingerprint: (id, address) => id == fromId ? from.fingerprint : null,
      pins: pins,
    );
    final server = await me.bind([from]);
    server.listen((req) async {
      if (!await receive.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return server;
  }

  List<OutgoingFile> oneFile(String name) {
    final file = File('${root.path}/$name')..writeAsStringSync('abc');
    return [(path: file.path, name: name, size: 3)];
  }

  test('accepting a request from the device with the new key pins it, and sending works again', () async {
    // The phone accepted the office PC when it held its old key.
    final phonePins = PinStore.memory();
    await phonePins.pin('office-pc', oldOffice.fingerprint);
    final atOffice = <ConnectionRequest>[];
    final atPhone = <ConnectionRequest>[];
    final officeServer = await door(office, phone, 'phone', PinStore.memory(), atOffice);
    final phoneServer = await door(phone, office, 'office-pc', phonePins, atPhone);
    try {
      final fromPhone = SendHttp(
          getLocalName: () => 'Ali Phone',
          getLocalId: () => 'phone',
          getContext: phone.identity.clientContext,
          pins: phonePins);
      final fromOffice = SendHttp(
          getLocalName: () => 'Office PC', getLocalId: () => 'office-pc', getContext: office.identity.clientContext);
      final target = office.device(officeServer.port, id: 'office-pc');

      expect(await fromPhone.sendFiles(oneFile('a.txt'), target), SendOutcome.keyChanged);
      expect(atOffice, isEmpty);

      // The way out: from the office PC to the phone, accepted there once.
      expect(await fromOffice.sendFiles(oneFile('b.txt'), phone.device(phoneServer.port, id: 'phone')),
          SendOutcome.sent);
      expect(atPhone.single.keyChanged, isTrue, reason: 'the question warned of the new key');
      expect(phonePins.pinned('office-pc'), office.fingerprint);

      expect(await fromPhone.sendFiles(oneFile('c.txt'), target), SendOutcome.sent);
      expect(atOffice, hasLength(1));
    } finally {
      await officeServer.close(force: true);
      await phoneServer.close(force: true);
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('the message tells what to do, naming the button the question shows (${locale.languageCode})', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final text in [l10n.sendNewKey, l10n.shareNewKey]) {
        expect(text, contains(l10n.accept));
      }
      expect(l10n.shareNewKey, isNot(l10n.sendNewKey), reason: 'not sending and not opening a folder are two things');
    });
  }
}
