@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/one_question.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/chat/data/chat_http.dart';
import 'package:apex_file_share/features/chat/logic/chat_access.dart';
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

import '../identity/tls_peer.dart';

/// The router gives an address to another device the next day: the chat,
/// its unread count, its token and its block belong to the certificate of
/// the device (owner decision), not to its address. No widget test here: one
/// in the file replaces HttpClient with a fake that answers 400, and the door
/// tests would pass for nothing. The door with several certificates is in
/// chat_fingerprint_test.dart.

/// Yesterday's device at 10.0.0.7, and today's, given the same address.
final _first = Device(
    id: 'laptop-1', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000, fingerprint: 'a' * 64);
final _second = Device(
    id: 'phone-2', name: 'Guest Phone', type: 'phone', ip: '10.0.0.7', port: 4000, fingerprint: 'b' * 64);

ChatStore _store() => ChatStore(send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null));

/// The real chat door behind a real server on 127.0.0.1.
class _Door {
  _Door._(this._server);
  final HttpServer _server;
  final asked = <ConnectionRequest>[];
  final delivered = <IncomingChat>[];
  bool? Function(ConnectionRequest) decide = (_) => true;

  static Future<_Door> start(ChatAccess access, {Duration wait = const Duration(seconds: 5)}) async {
    final server = await bindReceiver();
    final d = _Door._(server);
    final door = ChatHttp(
      expectedFingerprint: await heardSender(),
      pins: PinStore.memory(),
      onRequest: (r) {
        d.asked.add(r);
        final answer = d.decide(r);
        if (answer != null) {
          r.onResponse(answer);
        }
      },
      onMessage: d.delivered.add,
      access: access,
      question: OneQuestion(),
      decisionTimeout: wait,
    );
    server.listen((req) async {
      if (!await door.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return d;
  }

  Future<void> stop() => _server.close(force: true);

  /// A message from [from] (a loopback address) with the body [body].
  Future<({int status, Map json})> post(Map<String, Object?> body,
      {String from = '127.0.0.1', String? token}) async {
    final bytes = utf8.encode(jsonEncode(body));
    final socket = await senderSocket(_server.port, from: from);
    final crlf = String.fromCharCodes(const [13, 10]);
    final head = StringBuffer()
      ..write('POST ${ApexProtocol.chatPath} HTTP/1.1$crlf')
      ..write('Host: 127.0.0.1:${_server.port}$crlf')
      ..write('Content-Type: application/json$crlf')
      ..write('Content-Length: ${bytes.length}$crlf')
      ..write('Connection: close$crlf')
      ..write('${ApexProtocol.versionHeader}: ${ApexProtocol.version}$crlf');
    if (token != null) {
      head.write('${ApexProtocol.tokenHeader}: $token$crlf');
    }
    head.write(crlf);
    socket
      ..add(utf8.encode(head.toString()))
      ..add(bytes);
    await socket.flush();
    final reply = await utf8.decoder.bind(socket).join();
    socket.destroy();
    final status = int.parse(reply.split(' ')[1]);
    final start = reply.indexOf('{');
    final json = start < 0 ? <String, Object?>{} : jsonDecode(reply.substring(start, reply.lastIndexOf('}') + 1)) as Map;
    return (status: status, json: json);
  }
}

Map<String, Object?> _msg(String id, String text) => {'id': id, 'name': 'Phone', 'text': text};

void main() {
  setUpAll(loadPeers);
  group('the store', () {
    test('a new device at the same address gets an empty chat, with nothing unread', () {
      final store = _store()..receive(_first.chatPeer, 'Office PC', 'the wifi key is 8812');
      expect(store.thread(_second.chatKey), isNull);
      expect(store.unread(_second.chatKey), 0);
      expect(store.unread(_first.chatKey), 1);
    });

    test('a new device at the same address does not inherit the block', () {
      final store = _store()..block(_first.chatPeer);
      expect(store.isBlocked(_second.chatPeer), isFalse);
      expect(store.canBlock(_second.chatPeer), isTrue);
      store.receive(_second.chatPeer, 'Guest Phone', 'hello');
      expect(store.thread(_second.chatKey)!.messages.single.text, 'hello');
    });

    test('what the user writes to the new device stays in its own chat', () async {
      final to = <String>[];
      final store = ChatStore(send: (t, d, k) async {
        to.add(d.id);
        return (outcome: ChatOutcome.sent, token: null);
      })
        ..receive(_first.chatPeer, 'Office PC', 'old');
      await store.write(_second, 'new');
      expect(store.thread(_first.chatKey)!.messages.map((m) => m.text), ['old']);
      expect(store.thread(_second.chatKey)!.messages.map((m) => m.text), ['new']);
      expect(to, ['phone-2']);
    });

    test('the same device back at another address after sleep keeps its chat', () {
      final store = _store()..receive(_first.chatPeer, 'Office PC', 'before sleep');
      final back = _first.copyWith(ip: '10.0.0.8', port: 4123);
      store.receive(back.chatPeer, 'Office PC', 'after sleep');
      expect(store.thread(back.chatKey)!.messages.map((m) => m.text), ['before sleep', 'after sleep']);
    });

    test('the token kept for one device is not sent to the next one at its address', () async {
      final tokens = <String?>[];
      final store = ChatStore(send: (t, d, k) async {
        tokens.add(k);
        return (outcome: ChatOutcome.sent, token: 'issued-to-${d.id}');
      });
      await store.write(_first, 'one');
      await store.write(_second, 'two');
      await store.write(_first, 'three');
      expect(tokens, [null, null, 'issued-to-laptop-1']);
    });

    FileReceivedEvent got(Device from, int batch, {bool withCertificate = true}) => FileReceivedEvent(
          fileName: 'report.pdf',
          fileSize: 10,
          fromDevice: 'PC',
          fromAddress: from.ip,
          fromId: from.id,
          fromFingerprint: withCertificate ? from.fingerprint : null,
          batchId: batch,
          filePath: '/save/report.pdf',
        );

    test("a received file goes to the chat of its sender's certificate", () {
      final store = _store()
        ..receivedFile(got(_first, 1))
        ..receivedFile(got(_second, 2));
      expect(store.thread(_first.chatKey)!.messages.single.files.single.name, 'report.pdf');
      expect(store.thread(_second.chatKey)!.messages, hasLength(1),
          reason: 'its own line, not added to the first device line');
    });

    test('a file without a sender id or certificate gets no line', () {
      var changed = 0;
      _store()
        ..addListener(() => changed++)
        ..receivedFile(FileReceivedEvent(
            fileName: 'a.pdf', fileSize: 1, fromDevice: 'PC', fromAddress: '10.0.0.7', filePath: '/a'))
        ..receivedFile(got(_first, 3, withCertificate: false));
      expect(changed, 0);
    });
  });

  group('the chat door', () {
    late _Door door;
    late ChatAccess access;
    setUp(() async {
      access = ChatAccess();
      door = await _Door.start(access);
    });
    tearDown(() => door.stop());

    test('a message without an id is refused and asks nobody', () async {
      for (final body in [
        {'name': 'Phone', 'text': 'hi'},
        {'id': 42, 'name': 'Phone', 'text': 'hi'},
        {'id': '   ', 'name': 'Phone', 'text': 'hi'},
      ]) {
        final r = await door.post(body);
        expect(r.status, HttpStatus.badRequest, reason: '$body');
        expect(r.json['error'], 'bad_message');
      }
      expect(door.asked, isEmpty);
      expect(door.delivered, isEmpty);
    });

    test('a message carries the id it was sent with', () async {
      await door.post(_msg('laptop-1', 'hi'));
      expect(door.delivered.single.id, 'laptop-1');
      expect(door.delivered.single.address, '127.0.0.1');
      expect(door.asked.single.device.id, 'laptop-1');
    });

    test('the same device back at the same address goes on unasked', () async {
      final token = (await door.post(_msg('laptop-1', 'before sleep'))).json['token'] as String;
      final r = await door.post(_msg('laptop-1', 'after sleep'), token: token);
      expect(r.json['delivered'], isTrue);
      expect(door.asked, hasLength(1));
    });
  });

  group('the sender', () {
    test('a chat message carries this device id', () async {
      final door = await _Door.start(ChatAccess());
      try {
        final target = Device(id: 't', name: 'TV', type: 'tv', ip: '127.0.0.1', port: door._server.port, fingerprint: testReceiver.fingerprint);
        final r = await SendHttp(getContext: senderContext, getLocalName: () => 'My PC', getLocalId: () => 'laptop-1')
            .sendChat('hi', target, null);
        expect(r.outcome, ChatOutcome.sent);
        expect(door.delivered.single.id, 'laptop-1');
      } finally {
        await door.stop();
      }
    });
  });

  group('the file door', () {
    late Directory root;
    late HttpServer server;
    late List<FileReceivedEvent> events;
    late List<ConnectionRequest> asked;

    setUp(() async {
      TransferProgressService().clearProgress();
      root = await Directory.systemTemp.createTemp('apex_device_key_');
      Directory('${root.path}/tmp').createSync();
      events = [];
      asked = [];
      final receive = ReceiveHttp(
        expectedFingerprint: await heardSender(),
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
        onFileReceived: events.add,
      );
      server = await bindReceiver();
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

    test('an offer without an id is refused and asks nobody', () async {
      final client = await senderClient();
      try {
        for (final id in [null, 7, '']) {
          final req = await client.postUrl(Uri.https('127.0.0.1:${server.port}', ApexProtocol.offerPath));
          req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
          req.write(jsonEncode({
            if (id != null) 'id': id,
            'name': 'Phone',
            'files': [{'name': 'a.txt', 'size': 3}],
          }));
          final res = await req.close();
          final text = await res.transform(utf8.decoder).join();
          expect(res.statusCode, HttpStatus.badRequest, reason: '$id');
          expect((jsonDecode(text) as Map)['error'], 'bad_offer');
        }
        expect(asked, isEmpty);
      } finally {
        client.close(force: true);
      }
    });

    test("files sent carry this device id, and their line goes to its certificate's chat", () async {
      final file = File('${root.path}/a.txt')..writeAsStringSync('abc');
      final target = Device(id: 'r', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: server.port, fingerprint: testReceiver.fingerprint);
      final outcome = await SendHttp(getContext: senderContext, getLocalName: () => 'Office PC', getLocalId: () => 'laptop-1')
          .sendFiles([(path: file.path, name: 'a.txt', size: 3)], target);
      expect(outcome, SendOutcome.sent);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (events.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(events.single.fromId, 'laptop-1');
      expect(events.single.fromFingerprint, testSender.fingerprint);
      expect(asked.single.device.id, 'laptop-1');
      final store = _store()..receivedFile(events.single);
      expect(store.thread(ChatKey(testSender.fingerprint))!.messages.single.files.single.name, 'a.txt');
      expect(store.thread(ChatKey(testReceiver.fingerprint)), isNull);
    });
  });
}
