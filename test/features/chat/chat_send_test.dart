@TestOn('vm')
library;

import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/one_question.dart';
import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/chat/data/chat_http.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';

void main() {
  setUpAll(loadPeers);
  late HttpServer server;
  late List<ConnectionRequest> asked;
  late List<IncomingChat> delivered;
  late OneQuestion question;
  final send = SendHttp(getContext: senderContext, getLocalName: () => 'My PC', getLocalId: () => 'test-id');

  Future<Device> start({bool? Function(ConnectionRequest)? decide, bool withChat = true}) async {
    asked = [];
    delivered = [];
    question = OneQuestion();
    server = await bindReceiver();
    final door = ChatHttp(
      expectedFingerprint: await heardSender(),
      pins: PinStore.memory(),
      onRequest: (r) {
        asked.add(r);
        final answer = decide == null ? true : decide(r);
        if (answer != null) {
          r.onResponse(answer);
        }
      },
      onMessage: delivered.add,
      question: question,
      decisionTimeout: const Duration(milliseconds: 200),
    );
    server.listen((req) async {
      if (!withChat || !await door.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return Device(id: 't', name: 'TV', type: 'tv', ip: '127.0.0.1', port: server.port, fingerprint: testReceiver.fingerprint);
  }

  tearDown(() => server.close(force: true));

  test('accepted: sent, with a token that lets the next message in unasked', () async {
    final target = await start();
    final first = await send.sendChat('hello', target, null);
    expect(first.outcome, ChatOutcome.sent);
    expect(first.token, isNotNull);
    final second = await send.sendChat('again', target, first.token);
    expect(second.outcome, ChatOutcome.sent);
    expect(second.token, first.token);
    expect(asked, hasLength(1));
    expect(delivered.map((m) => m.name).toSet(), {'My PC'});
    expect(delivered.map((m) => m.text), ['hello', 'again']);
  });

  test('refused: declined and no token', () async {
    final target = await start(decide: (_) => false);
    final r = await send.sendChat('hello', target, null);
    expect(r.outcome, ChatOutcome.declined);
    expect(r.token, isNull);
  });

  test('never answered: reported as no answer, not as a refusal', () async {
    final target = await start(decide: (_) => null);
    expect((await send.sendChat('hello', target, null)).outcome, ChatOutcome.noAnswer);
  });

  test('a receiver without chat means "update the app"', () async {
    final target = await start(withChat: false);
    expect((await send.sendChat('hello', target, null)).outcome, ChatOutcome.updateRequired);
  });

  test('busy with another question: busy', () async {
    final target = await start();
    question.take();
    expect((await send.sendChat('hello', target, null)).outcome, ChatOutcome.busy);
    question.release();
  });

  test('too long is refused here, before anything is sent', () async {
    final target = await start();
    final r = await send.sendChat('a' * (TransferRules.chatTextLimit + 1), target, null);
    expect(r.outcome, ChatOutcome.tooLong);
    expect(asked, isEmpty);
  });

  test('nobody listening: failed', () async {
    final target = await start();
    await server.close(force: true);
    expect((await send.sendChat('hello', target, null)).outcome, ChatOutcome.failed);
  });
}
