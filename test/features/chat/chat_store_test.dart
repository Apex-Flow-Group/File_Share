import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

const _tv = Device(id: 't', name: 'TV', type: 'tv', ip: '10.0.0.5', port: 4000);

void main() {
  late List<({String text, String? token})> sent;
  late List<({ChatOutcome outcome, String? token})> answers;
  late ChatStore store;

  setUp(() {
    sent = [];
    answers = [];
    store = ChatStore(send: (text, target, token) async {
      sent.add((text: text, token: token));
      return answers.isEmpty ? (outcome: ChatOutcome.sent, token: 'T1') : answers.removeAt(0);
    });
  });

  test('a message shows as sending, then sent', () async {
    final done = store.write(_tv, 'hello');
    expect(store.thread(_tv.ip)!.messages.single.status, ChatStatus.sending);
    await done;
    expect(store.thread(_tv.ip)!.messages.single.status, ChatStatus.sent);
  });

  test('the token from the first message goes with the next', () async {
    await store.write(_tv, 'one');
    answers.add((outcome: ChatOutcome.sent, token: 'T1'));
    await store.write(_tv, 'two');
    expect(sent.map((s) => s.token), [null, 'T1']);
  });

  test('a message that did not arrive stays, with its reason, and is not resent by itself', () async {
    answers.add((outcome: ChatOutcome.busy, token: null));
    await store.write(_tv, 'hello');
    final m = store.thread(_tv.ip)!.messages.single;
    expect(m.status, ChatStatus.failed);
    expect(m.failure, ChatOutcome.busy);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sent, hasLength(1));

    await store.retry(_tv, m);
    expect(sent, hasLength(2));
    expect(m.status, ChatStatus.sent);
    expect(m.failure, isNull);
    expect(store.thread(_tv.ip)!.messages, hasLength(1), reason: 'retried in place, not copied');
  });

  test('a network failure keeps the token; a refusal drops it', () async {
    await store.write(_tv, 'one');
    answers.add((outcome: ChatOutcome.failed, token: null));
    await store.write(_tv, 'two');
    answers.add((outcome: ChatOutcome.declined, token: null));
    await store.write(_tv, 'three');
    await store.write(_tv, 'four');
    expect(sent.map((s) => s.token), [null, 'T1', 'T1', null]);
  });

  test('only a failed message of mine can be retried', () async {
    store.receive(_tv.ip, 'TV', 'from tv');
    await store.retry(_tv, store.thread(_tv.ip)!.messages.single);
    await store.write(_tv, 'mine');
    await store.retry(_tv, store.thread(_tv.ip)!.messages.last);
    expect(sent, hasLength(1));
  });

  test('received messages count as unread until the chat is opened', () {
    store.receive(_tv.ip, 'TV', 'a');
    store.receive(_tv.ip, 'TV', 'b');
    expect(store.unread(_tv.ip), 2);
    store.opened(_tv.ip);
    expect(store.unread(_tv.ip), 0);
    store.receive(_tv.ip, 'TV', 'c');
    expect(store.unread(_tv.ip), 0, reason: 'the user is looking at it');
    store.closed(_tv.ip);
    store.receive(_tv.ip, 'TV', 'd');
    expect(store.unread(_tv.ip), 1);
  });

  test('a new message is announced only when its chat is not open', () async {
    final heard = <String>[];
    final sub = store.incoming.listen((t) => heard.add(t.address));
    store.receive('10.0.0.9', 'Phone', 'hi');
    store.opened(_tv.ip);
    store.receive(_tv.ip, 'TV', 'seen');
    await Future<void>.delayed(Duration.zero);
    expect(heard, ['10.0.0.9']);
    await sub.cancel();
  });

  test('chats are kept apart by address', () async {
    store.receive('10.0.0.1', 'A', 'one');
    store.receive('10.0.0.2', 'B', 'two');
    expect(store.thread('10.0.0.1')!.messages.single.text, 'one');
    expect(store.thread('10.0.0.2')!.messages.single.text, 'two');
  });

  test('a chat keeps at most the latest messages, so memory has a ceiling', () {
    for (var i = 0; i < ChatStore.maxMessagesPerThread + 5; i++) {
      store.receive(_tv.ip, 'TV', '$i');
    }
    final messages = store.thread(_tv.ip)!.messages;
    expect(messages, hasLength(ChatStore.maxMessagesPerThread));
    expect(messages.first.text, '5');
  });
}
