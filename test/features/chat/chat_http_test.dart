@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/one_question.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/chat/data/chat_http.dart';
import 'package:apex_file_share/features/chat/logic/chat_access.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real chat door behind a real server on 127.0.0.1. Every first message
/// is accepted unless [decide] says otherwise (null: the user never answers).
class _Server {
  _Server._(this._server, this.question);

  final HttpServer _server;
  final OneQuestion question;
  final asked = <ConnectionRequest>[];
  final delivered = <IncomingChat>[];
  final blocked = <ChatKey>[];
  int get port => _server.port;

  static Future<_Server> start({
    bool? Function(ConnectionRequest)? decide,
    Duration decisionTimeout = TransferRules.decisionTimeout,
    ChatAccess? access,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = _Server._(server, OneQuestion());
    final door = ChatHttp(
      onRequest: (r) {
        s.asked.add(r);
        final answer = decide == null ? true : decide(r);
        if (answer != null) {
          r.onResponse(answer);
        }
      },
      onMessage: s.delivered.add,
      onBlocked: s.blocked.add,
      access: access,
      question: s.question,
      decisionTimeout: decisionTimeout,
    );
    server.listen((req) async {
      if (!await door.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return s;
  }

  Future<void> stop() => _server.close(force: true);

  /// Sends a message from [from] (a loopback address) and returns the answer.
  Future<({int status, Map json})> send(
    Object? text, {
    String? token,
    String? version = '${ApexProtocol.version}',
    String method = 'POST',
    String from = '127.0.0.1',
    String name = 'Test Phone',
    String id = 'test-phone',
  }) async {
    final body = utf8.encode(jsonEncode({'id': id, 'name': name, 'text': text}));
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port,
        sourceAddress: InternetAddress(from));
    final head = StringBuffer()
      ..write('$method ${ApexProtocol.chatPath} HTTP/1.1\r\n')
      ..write('Host: 127.0.0.1:$port\r\n')
      ..write('Content-Type: application/json\r\n')
      ..write('Content-Length: ${body.length}\r\n')
      ..write('Connection: close\r\n');
    if (version != null) {
      head.write('${ApexProtocol.versionHeader}: $version\r\n');
    }
    if (token != null) {
      head.write('${ApexProtocol.tokenHeader}: $token\r\n');
    }
    head.write('\r\n');
    socket.add(utf8.encode(head.toString()));
    socket.add(body);
    await socket.flush();
    final reply = await utf8.decoder.bind(socket).join();
    socket.destroy();
    final status = int.parse(reply.split(' ')[1]);
    final split = reply.indexOf('\r\n\r\n');
    final rest = split < 0 ? '' : reply.substring(split + 4);
    final start = rest.indexOf('{');
    final json = start < 0 ? <String, Object?>{} : jsonDecode(rest.substring(start, rest.lastIndexOf('}') + 1)) as Map;
    return (status: status, json: json);
  }
}

void main() {
  late _Server server;
  tearDown(() => server.stop());

  test('a message with no version is refused with "update required" and asks nobody', () async {
    server = await _Server.start();
    final r = await server.send('hi', version: null);
    expect(r.status, HttpStatus.upgradeRequired);
    expect(r.json['error'], ApexProtocol.updateRequired);
    expect(server.asked, isEmpty);
    expect(server.delivered, isEmpty);
  });

  test('an older or newer version is refused the same way', () async {
    server = await _Server.start();
    for (final v in ['${ApexProtocol.version - 1}', '${ApexProtocol.version + 1}']) {
      expect((await server.send('hi', version: v)).status, HttpStatus.upgradeRequired);
    }
    expect(server.asked, isEmpty);
  });

  test('only POST is answered', () async {
    server = await _Server.start();
    expect((await server.send('hi', method: 'PUT')).status, HttpStatus.methodNotAllowed);
    expect(server.asked, isEmpty);
  });

  test('the first message asks the user, and nothing is shown before the answer', () async {
    final answer = Completer<bool>();
    late _Server s;
    s = server = await _Server.start(decide: (r) {
      // Asked, but still waiting: the text must not be out yet.
      expect(s.delivered, isEmpty);
      answer.future.then(r.onResponse);
      return null;
    });
    final reply = server.send('hello');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.asked, hasLength(1));
    expect(server.asked.single.kind, RequestKind.chat);
    expect(server.asked.single.device.ip, '127.0.0.1');
    expect(server.delivered, isEmpty);
    answer.complete(true);
    final r = await reply;
    expect(r.status, HttpStatus.ok);
    expect(r.json['delivered'], isTrue);
    expect(r.json['token'], isA<String>());
    expect(server.delivered.single.text, 'hello');
    expect(server.delivered.single.address, '127.0.0.1');
  });

  test('with the token, later messages arrive without asking again', () async {
    server = await _Server.start();
    final token = (await server.send('one')).json['token'] as String;
    final r = await server.send('two', token: token);
    expect(r.json['delivered'], isTrue);
    expect(server.asked, hasLength(1));
    expect([for (final m in server.delivered) m.text], ['one', 'two']);
  });

  test('the token is bound to the address it was given to', () async {
    server = await _Server.start();
    final token = (await server.send('one')).json['token'] as String;
    await server.send('two', token: token, from: '127.0.0.2');
    expect(server.asked, hasLength(2), reason: 'another address is asked about again');
    expect(server.asked.last.device.ip, '127.0.0.2');
  });

  test('the block button turns a device away at the door, and unblocking asks again', () async {
    final access = ChatAccess();
    server = await _Server.start(access: access);
    final token = (await server.send('one')).json['token'] as String;
    access.block(chatKey('test-phone', '127.0.0.1'));
    final blocked = await server.send('two', token: token);
    expect(blocked.json['accepted'], isFalse);
    expect(server.asked, hasLength(1));
    access.unblock(chatKey('test-phone', '127.0.0.1'));
    await server.send('three', token: token);
    expect(server.asked, hasLength(2), reason: 'asked again, the old token stays dead');
    expect(server.delivered.map((m) => m.text), ['one', 'three']);
  });

  test('a refused device writes nothing and is not asked about again', () async {
    server = await _Server.start(decide: (_) => false);
    final first = await server.send('spam');
    expect(first.json['accepted'], isFalse);
    expect(first.json.containsKey('reason'), isFalse);
    final second = await server.send('spam again');
    expect(second.json['accepted'], isFalse);
    expect(server.asked, hasLength(1));
    expect(server.delivered, isEmpty);
    expect(server.blocked, [chatKey('test-phone', '127.0.0.1')], reason: 'the screen learns it is blocked');
  });

  test('no answer in time is not a refusal, and the same address is not asked again at once', () async {
    server = await _Server.start(decide: (_) => null, decisionTimeout: const Duration(milliseconds: 100));
    final r = await server.send('hello');
    expect(r.json['accepted'], isFalse);
    expect(r.json['reason'], ApexProtocol.noAnswer);
    final again = await server.send('hello');
    expect(again.json['reason'], ApexProtocol.noAnswer, reason: 'told to try later, not refused');
    expect(server.asked, hasLength(1));
    expect(server.delivered, isEmpty);
  });

  test('after a restart an old token is unknown, so the user is asked again', () async {
    server = await _Server.start();
    final token = (await server.send('one')).json['token'] as String;
    await server.stop();
    server = await _Server.start();
    final r = await server.send('two', token: token);
    expect(server.asked, hasLength(1));
    expect(r.json['token'], isNot(token));
  });

  test('a message over the limit is refused before asking', () async {
    server = await _Server.start();
    final r = await server.send('a' * (TransferRules.chatTextLimit + 1));
    expect(r.status, HttpStatus.requestEntityTooLarge);
    expect(r.json['error'], ApexProtocol.tooLong);
    expect(server.asked, isEmpty);
  });

  test('a message at the limit arrives', () async {
    server = await _Server.start();
    await server.send('a' * TransferRules.chatTextLimit);
    expect(server.delivered.single.text.length, TransferRules.chatTextLimit);
  });

  test('an empty or blank message, or one that is not text, is refused before asking', () async {
    server = await _Server.start();
    for (final text in ['', '   \n ', null, 42]) {
      expect((await server.send(text)).status, HttpStatus.badRequest, reason: '$text');
    }
    expect(server.asked, isEmpty);
  });

  test('while another question waits for the user, the message is refused as busy', () async {
    server = await _Server.start();
    expect(server.question.take(), isTrue);
    final r = await server.send('hello');
    expect(r.status, HttpStatus.tooManyRequests);
    expect(server.asked, isEmpty);
    server.question.release();
  });

  test('control characters and direction overrides do not reach the screen', () async {
    server = await _Server.start();
    final raw = String.fromCharCodes(
        [...'pay '.codeUnits, 0x202E, ...'moc.knab'.codeUnits, 0x07, 0x0A, ...'ok'.codeUnits]);
    await server.send(raw);
    expect(server.delivered.single.text, 'pay moc.knab\nok');
  });

  test('the name the device gave is cleaned and kept for its later messages', () async {
    server = await _Server.start();
    final raw = String.fromCharCodes([...'Phone'.codeUnits, 0x202E, 0x0A, ...'X'.codeUnits]);
    final token = (await server.send('one', name: raw)).json['token'] as String;
    await server.send('two', token: token, name: 'Someone Else');
    expect(server.delivered.map((m) => m.name).toSet(), {'Phone X'});
  });
}
