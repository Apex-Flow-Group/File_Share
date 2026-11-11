@TestOn('vm')
library;

import 'dart:io';

import 'package:apex_file_share/core/one_question.dart';
import 'package:apex_file_share/features/chat/logic/chat_access.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/chat/logic/chat_text.dart';
import 'package:apex_file_share/features/receive/logic/nearby_door.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

/// No widget test here: one in the file replaces HttpClient with a fake
/// that answers 400 to everything, and the reply tests would pass for nothing.
void main() {
  test('a question nobody answered is not raised again by the same address for a while', () {
    var now = DateTime(2026, 11, 12, 9);
    final access = ChatAccess(clock: () => now);
    access.unanswered('10.0.0.9');
    expect(access.isQuiet('10.0.0.9'), isTrue);
    expect(access.isQuiet('10.0.0.8'), isFalse, reason: 'other addresses are unaffected');
    now = now.add(ChatAccess.quietAfterNoAnswer);
    expect(access.isQuiet('10.0.0.9'), isFalse);
  });

  test('accepting ends the quiet period', () {
    final access = ChatAccess()..unanswered('10.0.0.9');
    access.admit('10.0.0.9', 'Phone');
    expect(access.isQuiet('10.0.0.9'), isFalse);
  });

  test('invisible characters do not reach the screen', () {
    final raw = String.fromCharCodes([
      ...'IBAN 12'.codeUnits, 0x200B, ...'34'.codeUnits, 0x200F, 0x061C, 0x2060,
      0x2028, ...'56'.codeUnits, 0xE0041, 0x206A,
    ]);
    expect(cleanChatText(raw), 'IBAN 123456');
  });

  test('a device sending without pause is announced at most once per period', () async {
    var now = DateTime(2026, 11, 12, 9);
    final store = ChatStore(
        send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null), clock: () => now);
    final heard = <String>[];
    store.incoming.listen((t) => heard.add(t.address));
    for (var i = 0; i < 20; i++) {
      store.receive('10.0.0.9', 'TV', '$i');
    }
    now = now.add(ChatStore.announceEvery);
    store.receive('10.0.0.9', 'TV', 'later');
    await Future<void>.delayed(Duration.zero);
    expect(heard, ['10.0.0.9', '10.0.0.9']);
    expect(store.unread('10.0.0.9'), 21, reason: 'every message is still kept and counted');
  });

  test('the Nearby door waits its turn behind a question from another door', () async {
    final question = OneQuestion();
    final asked = <Object>[];
    final door = NearbyDoor(
      onConnectionRequest: asked.add,
      send: (_, __) async {},
      question: question,
      decisionTimeout: const Duration(milliseconds: 100),
    );
    expect(question.take(), isTrue, reason: 'a chat question is on screen');
    expect(await door.mayConnect('ep1', 'Phone'), isFalse);
    expect(asked, isEmpty);
    question.release();
  });

  group('a reply that is not a chat reply', () {
    late HttpServer server;
    tearDown(() => server.close(force: true));

    Future<Device> serve(Future<void> Function(HttpResponse) answer) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        await req.drain<void>();
        await answer(req.response);
      });
      return Device(id: 'x', name: 'X', type: 'desktop', ip: '127.0.0.1', port: server.port);
    }

    test('a huge one fails the message instead of filling the memory', () async {
      final target = await serve((res) async {
        res.write('{"delivered": true, "pad": "${'x' * (64 * 1024)}"}');
        await res.close();
      });
      final r = await SendHttp(getLocalName: () => 'Me').sendChat('hi', target, null);
      expect(r.outcome, ChatOutcome.failed);
    });

    test('one that never ends fails the message instead of leaving it "sending"', () async {
      // Promises 1000 bytes, sends a few, then goes quiet with the line open.
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      raw.listen((s) {
        s.listen((_) {
          final crlf = String.fromCharCodes(const [13, 10]);
          s.write('HTTP/1.1 200 OK${crlf}Content-Type: application/json$crlf'
              'Content-Length: 1000$crlf$crlf{"delivered"');
        });
      });
      final target = Device(id: 'x', name: 'X', type: 'desktop', ip: '127.0.0.1', port: raw.port);
      final sw = Stopwatch()..start();
      final r = await SendHttp(getLocalName: () => 'Me').sendChat('hi', target, null);
      expect(r.outcome, ChatOutcome.failed);
      expect(sw.elapsed, greaterThanOrEqualTo(const Duration(seconds: 9)),
          reason: 'it ended by the reply time limit, not by an error');
      await raw.close();
    }, timeout: const Timeout(Duration(seconds: 40)));
  });
}
