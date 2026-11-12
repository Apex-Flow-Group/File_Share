@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/features/chat/data/chat_http.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tls_peer.dart';

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

/// The three doors behind one real TLS server on 127.0.0.1, as ApexCore
/// serves them. [heard] is what discovery heard: the fingerprint of each id.
class _Device {
  _Device._(this.server, this.pins, this._root);

  final HttpServer server;
  final PinStore pins;
  final Directory _root;
  final asked = <ConnectionRequest>[];
  final chats = <IncomingChat>[];
  final files = <FileReceivedEvent>[];
  final heard = <String, String>{};
  bool answer = true;

  int get port => server.port;

  static Future<_Device> start(TlsPeer me, List<TlsPeer> known, {required File pinFile}) async {
    TransferProgressService().clearProgress();
    final root = await Directory.systemTemp.createTemp('apex_identity_doors_');
    Directory('${root.path}/tmp').createSync();
    Directory('${root.path}/share').createSync();
    File('${root.path}/share/salary.xlsx').writeAsStringSync('private');
    final server = await me.bind(known);
    final d = _Device._(server, await PinStore.open(pinFile), root);
    String? expected(String id, String address) => address == '127.0.0.1' ? d.heard[id] : null;
    void ask(ConnectionRequest r) {
      d.asked.add(r);
      r.onResponse(d.answer);
    }

    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => Directory('${root.path}/tmp'),
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
      ),
      onConnectionRequest: ask,
      onFileReceived: d.files.add,
      expectedFingerprint: expected,
      pins: d.pins,
    );
    final chat = ChatHttp(onRequest: ask, onMessage: d.chats.add, expectedFingerprint: expected, pins: d.pins);
    final share = ShareFolderHttp(
      isEnabled: () => true,
      allowUploads: () => true,
      getLocalName: () => 'Office PC',
      service: _TempShareService('${root.path}/share'),
      onAccessRequest: ask,
      expectedFingerprint: expected,
      pins: d.pins,
    );
    server.listen((req) async {
      if (!await receive.handle(req) && !await chat.handle(req) && !await share.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return d;
  }

  Future<void> stop() async {
    await server.close(force: true);
    TransferProgressService().clearProgress();
    await _root.delete(recursive: true);
  }
}

/// Posts [body] to [path] with [client] and returns the status and answer.
Future<({int status, Map json})> _post(HttpClient client, int port, String path, Object body,
    {String? token}) async {
  try {
    final req = await client.postUrl(Uri.https('127.0.0.1:$port', path));
    req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
    if (token != null) {
      req.headers.set(ApexProtocol.tokenHeader, token);
    }
    req.write(jsonEncode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return (status: res.statusCode, json: (text.isEmpty ? {} : jsonDecode(text)) as Map);
  } finally {
    client.close(force: true);
  }
}

Map<String, Object> _offer(String id) => {
      'id': id,
      'name': 'Ali Phone',
      'files': [
        {'name': 'a.txt', 'size': 3},
      ],
    };

Map<String, Object> _chat(String id, String text) => {'id': id, 'name': 'Ali Phone', 'text': text};

Map<String, Object> _access(String id) => {'id': id, 'name': 'Ali Phone'};

void main() {
  late TlsPeer pc;
  late TlsPeer phone;
  late TlsPeer stranger;
  late Directory pinFolder;
  late _Device device;

  setUpAll(() async {
    pc = await TlsPeer.create();
    phone = await TlsPeer.create();
    stranger = await TlsPeer.create();
  });

  setUp(() async {
    pinFolder = await Directory.systemTemp.createTemp('apex_pins_');
    device = await _Device.start(pc, [phone, stranger], pinFile: File('${pinFolder.path}/pins.json'));
    device.heard['phone'] = phone.fingerprint;
  });

  tearDown(() async {
    await device.stop();
    await pinFolder.delete(recursive: true);
  });

  test('an accepted request from the device discovery heard gets through', () async {
    // Proves the refusals below are the doors', not a broken handshake.
    final offer = await _post(phone.client(pc), device.port, ApexProtocol.offerPath, _offer('phone'));
    expect([offer.status, offer.json['accepted']], [HttpStatus.ok, true]);
    final chat = await _post(phone.client(pc), device.port, ApexProtocol.chatPath, _chat('phone', 'hi'));
    expect([chat.status, chat.json['delivered']], [HttpStatus.ok, true]);
    final share = await _post(phone.client(pc), device.port, ShareFolderHttp.accessPath, _access('phone'));
    expect([share.status, share.json['accepted']], [HttpStatus.ok, true]);
    expect(device.asked.map((r) => r.fingerprint).toSet(), {phone.fingerprint},
        reason: 'Who is asking is the certificate it came with.');
    expect(device.chats.single.fingerprint, phone.fingerprint);
  });

  test('a plain HTTP request gets no answer from any door', () async {
    final client = HttpClient();
    for (final path in [ApexProtocol.offerPath, ApexProtocol.chatPath, ShareFolderHttp.accessPath]) {
      Object? failure;
      try {
        final req = await client.postUrl(Uri.http('127.0.0.1:${device.port}', path));
        req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
        req.write(jsonEncode(_chat('phone', 'hi')));
        final res = await req.close();
        await res.drain<void>();
      } catch (e) {
        failure = e;
      }
      expect(failure, isNotNull, reason: '$path answered over plain HTTP');
    }
    client.close(force: true);
    expect(device.asked, isEmpty);
  });

  test('a TLS request without a client certificate is refused and asks nobody', () async {
    for (final (path, body) in [
      (ApexProtocol.offerPath, _offer('phone')),
      (ApexProtocol.chatPath, _chat('phone', 'hi')),
      (ShareFolderHttp.accessPath, _access('phone')),
      (ApexProtocol.pingPath, const <String, Object>{}),
    ]) {
      final res = await _post(clientWithoutCertificate(), device.port, path, body);
      expect(res.status, HttpStatus.upgradeRequired, reason: path);
    }
    expect(device.asked, isEmpty);
    expect(device.chats, isEmpty);
  });

  test('a certificate other than the one discovery heard for that id is refused (403) and asks nobody',
      () async {
    // The stranger's certificate is trusted for the handshake, as every
    // device heard in discovery is, but it claims to be the phone.
    for (final (path, body) in [
      (ApexProtocol.offerPath, _offer('phone')),
      (ApexProtocol.chatPath, _chat('phone', 'hi')),
      (ShareFolderHttp.accessPath, _access('phone')),
    ]) {
      final res = await _post(stranger.client(pc), device.port, path, body);
      expect([res.status, res.json['error']], [HttpStatus.forbidden, ApexProtocol.wrongIdentity],
          reason: path);
    }
    expect(device.asked, isEmpty);
    expect(device.chats, isEmpty);
  });

  test('an id discovery never heard is refused (403) and asks nobody', () async {
    final res = await _post(stranger.client(pc), device.port, ApexProtocol.chatPath, _chat('unknown', 'hi'));
    expect(res.status, HttpStatus.forbidden);
    expect(device.asked, isEmpty);
  });

  test('an upload token works only with the certificate of the accepted offer', () async {
    final offer = await _post(phone.client(pc), device.port, ApexProtocol.offerPath, _offer('phone'));
    final token = (offer.json['tokens'] as List).single as String;
    final client = stranger.client(pc);
    try {
      final req = await client.postUrl(Uri.https('127.0.0.1:${device.port}', ApexProtocol.uploadPath));
      req.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..set(ApexProtocol.tokenHeader, token);
      req.contentLength = 3;
      req.add(utf8.encode('abc'));
      final res = await req.close();
      await res.drain<void>();
      expect(res.statusCode, HttpStatus.forbidden);
    } finally {
      client.close(force: true);
    }
    expect(device.files, isEmpty);
  });

  test('the sender refuses a server whose certificate is not the one discovery heard', () async {
    final send = SendHttp(
        getLocalName: () => 'Ali Phone', getLocalId: () => 'phone', getContext: phone.identity.clientContext);
    // The server is the PC, but discovery said this address is the stranger.
    final claimed = stranger.device(device.port);
    final chat = await send.sendChat('my password', claimed, null);
    expect(chat.outcome, ChatOutcome.failed);
    final file = File('${pinFolder.path}/a.txt')..writeAsStringSync('abc');
    final files = await send.sendFiles([(path: file.path, name: 'a.txt', size: 3)], claimed);
    expect(files, SendOutcome.failed);
    expect(device.asked, isEmpty, reason: 'Nothing reached the server.');
    expect(device.chats, isEmpty);

    final real = await send.sendChat('hello', pc.device(device.port), null);
    expect(real.outcome, ChatOutcome.sent, reason: 'The same sender reaches the server it expects.');
  });

  test('accepting pins the fingerprint, and the pin outlives a restart of the store', () async {
    await _post(phone.client(pc), device.port, ApexProtocol.chatPath, _chat('phone', 'the wifi password'));
    final file = File('${pinFolder.path}/pins.json');
    final reopened = await PinStore.open(file);
    expect(reopened.pinned('phone'), phone.fingerprint);
    expect(file.readAsStringSync(), isNot(contains('wifi password')),
        reason: 'Pins are identity; a message may be a password.');
    expect(file.readAsStringSync(), isNot(contains('Ali Phone')));

    // A second device: the file is written again, with both.
    device.heard['tablet'] = stranger.fingerprint;
    await _post(stranger.client(pc), device.port, ShareFolderHttp.accessPath, _access('tablet'));
    final again = await PinStore.open(file);
    expect([again.pinned('phone'), again.pinned('tablet')], [phone.fingerprint, stranger.fingerprint]);
  });

  test('accepting a known id with its new certificate pins the new one', () async {
    await _post(phone.client(pc), device.port, ApexProtocol.offerPath, _offer('phone'));
    device.heard['phone'] = stranger.fingerprint;
    await _post(stranger.client(pc), device.port, ApexProtocol.offerPath, _offer('phone'));
    expect(device.asked.last.keyChanged, isTrue);
    await _post(stranger.client(pc), device.port, ApexProtocol.offerPath, _offer('phone'));
    expect(device.asked.last.keyChanged, isFalse, reason: 'The user accepted it with this key.');
    expect((await PinStore.open(File('${pinFolder.path}/pins.json'))).pinned('phone'), stranger.fingerprint);
  });

  test('a refused device is not pinned', () async {
    device.answer = false;
    await _post(phone.client(pc), device.port, ApexProtocol.offerPath, _offer('phone'));
    expect((await PinStore.open(File('${pinFolder.path}/pins.json'))).pinned('phone'), isNull);
  });

  test('a known id with a new certificate is not trusted, and its request says the key changed',
      () async {
    final first = await _post(phone.client(pc), device.port, ApexProtocol.chatPath, _chat('phone', 'hi'));
    final token = first.json['token'] as String;
    expect(device.asked.single.keyChanged, isFalse);

    // The phone's id now comes with another certificate, and discovery heard it.
    device.heard['phone'] = stranger.fingerprint;
    device.answer = false;
    final again = await _post(stranger.client(pc), device.port, ApexProtocol.chatPath, _chat('phone', 'hi'),
        token: token);
    expect(again.json['delivered'], isNot(true), reason: 'The token was given to the old certificate.');
    expect(device.asked, hasLength(2), reason: 'Asked as a new device, not let in by its id.');
    expect(device.asked.last.keyChanged, isTrue);
    expect(device.asked.last.fingerprint, stranger.fingerprint);

    for (final (path, body) in [
      (ApexProtocol.offerPath, _offer('phone')),
      (ShareFolderHttp.accessPath, _access('phone')),
    ]) {
      await _post(stranger.client(pc), device.port, path, body);
      expect(device.asked.last.keyChanged, isTrue, reason: path);
    }
    expect(device.chats, hasLength(1));
  });
}
