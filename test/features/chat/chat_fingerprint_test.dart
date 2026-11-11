@TestOn('vm')
library;

import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';
import 'chat_door.dart';

/// Owner decision: a chat belongs to the certificate of the device, not to
/// the id and address it announces. Real TLS on 127.0.0.1, one certificate
/// per device. No widget test here: one replaces HttpClient with a fake.
void main() {
  late TlsPeer me;
  late TlsPeer laptop;
  late TlsPeer guest;
  late TlsPeer impostor;
  late ChatDoor door;

  setUpAll(() async {
    me = await TlsPeer.create();
    laptop = await TlsPeer.create();
    guest = await TlsPeer.create();
    impostor = await TlsPeer.create();
  });

  setUp(() async => door = await ChatDoor.start(me, [laptop, guest, impostor]));
  tearDown(() => door.stop());

  List<String> texts(TlsPeer p) =>
      [for (final m in door.store.thread(ChatKey(p.fingerprint))?.messages ?? const <ChatMessage>[]) m.text];

  group('the chat follows the certificate', () {
    test('the same device back at a new address keeps its chat, its token and its unread count', () async {
      door.hear(laptop, 'laptop-1');
      final first = await door.post(laptop, me, 'laptop-1', 'before sleep');
      final token = first.json['token'] as String;

      // After sleep the router gave it another address; discovery heard it there.
      door.hear(laptop, 'laptop-1', address: '127.0.0.2');
      final back = await door.post(laptop, me, 'laptop-1', 'after sleep', address: '127.0.0.2', token: token);
      expect(back.json['delivered'], isTrue);
      expect(door.asked, hasLength(1), reason: 'not asked again: same certificate');
      expect(texts(laptop), ['before sleep', 'after sleep']);
      expect(door.store.unread(ChatKey(laptop.fingerprint)), 2);
      expect(door.store.thread(ChatKey(laptop.fingerprint))!.address, '127.0.0.2',
          reason: 'replies go to where it is now');
    });

    test('a new device at an old address gets an empty chat and is asked about', () async {
      door.hear(laptop, 'laptop-1');
      final first = await door.post(laptop, me, 'laptop-1', 'the wifi key is 8812');
      final token = first.json['token'] as String;

      // The next day the router gives that address to a guest phone.
      door.hear(guest, 'phone-2');
      door.decide = (_) => false;
      final r = await door.post(guest, me, 'phone-2', 'hello', token: token);
      expect(r.json['delivered'], isNot(true), reason: 'the token was given to another certificate');
      expect(door.asked, hasLength(2));
      expect(texts(guest), isEmpty);
      expect(door.store.unread(ChatKey(guest.fingerprint)), 0);
      expect(texts(laptop), ['the wifi key is 8812']);
    });

    test("a device announcing a colleague's id with its own key gets its own empty chat", () async {
      door.hear(laptop, 'laptop-1');
      final first = await door.post(laptop, me, 'laptop-1', 'salary.xlsx is ready');
      final token = first.json['token'] as String;

      // The laptop left; another device took its address and announces its
      // id, with its own certificate. Discovery now hears that one.
      door.hear(impostor, 'laptop-1');
      final r = await door.post(impostor, me, 'laptop-1', 'send it again', token: token);
      expect(r.json['delivered'], isTrue, reason: 'the user accepted it as a new device');
      expect(door.asked, hasLength(2), reason: "the laptop's token does not let it in");
      expect(door.asked.last.keyChanged, isTrue, reason: 'the question says the key is new');
      expect(texts(laptop), ['salary.xlsx is ready'], reason: "it never reaches the laptop's chat");
      expect(texts(impostor), ['send it again']);
    });

    test('a question nobody answered quiets that certificate at any address, and no other device', () async {
      final quick = await ChatDoor.start(me, [laptop, guest], wait: const Duration(milliseconds: 100));
      try {
        quick
          ..hear(laptop, 'laptop-1')
          ..hear(laptop, 'laptop-1', address: '127.0.0.2')
          ..hear(guest, 'phone-2')
          ..decide = (_) => null;
        await quick.post(laptop, me, 'laptop-1', 'one');
        quick.decide = (_) => true;
        final moved = await quick.post(laptop, me, 'laptop-1', 'two', address: '127.0.0.2');
        expect(moved.json['accepted'], isFalse, reason: 'a new address does not end the quiet period');
        expect(quick.asked, hasLength(1));
        final other = await quick.post(guest, me, 'phone-2', 'hello');
        expect(other.json['delivered'], isTrue, reason: 'the next device at that address is asked');
      } finally {
        await quick.stop();
      }
    });
  });

  group('a block holds the key and the id (owner decision)', () {
    test('a refused device that comes back with a new key is still blocked, and nobody is asked', () async {
      door
        ..hear(laptop, 'laptop-1')
        ..decide = (_) => false;
      await door.post(laptop, me, 'laptop-1', 'spam');
      expect(door.asked, hasLength(1));

      // Reinstalled: a new certificate, the same id.
      door
        ..hear(guest, 'laptop-1')
        ..decide = (_) => true;
      final again = await door.post(guest, me, 'laptop-1', 'spam again');
      expect(again.json['accepted'], isFalse);
      expect(door.asked, hasLength(1), reason: 'blocked devices are not asked about');
      expect(door.store.isBlocked(chatPeer(guest.fingerprint, 'laptop-1', '127.0.0.1')), isTrue,
          reason: 'its card shows it blocked, with the unblock button');
      expect(texts(guest), isEmpty);
    });

    test('a blocked key announcing another id is still blocked', () async {
      door
        ..hear(laptop, 'laptop-1')
        ..hear(laptop, 'laptop-9')
        ..decide = (_) => false;
      await door.post(laptop, me, 'laptop-1', 'spam');
      door.decide = (_) => true;
      final again = await door.post(laptop, me, 'laptop-9', 'spam again');
      expect(again.json['accepted'], isFalse);
      expect(door.asked, hasLength(1));
    });

    test('the block button ends the token of every device with that key or id', () async {
      door.hear(laptop, 'laptop-1');
      final token = (await door.post(laptop, me, 'laptop-1', 'one')).json['token'] as String;
      door.store.block(chatPeer(guest.fingerprint, 'laptop-1', '127.0.0.1'));
      final r = await door.post(laptop, me, 'laptop-1', 'two', token: token);
      expect(r.json['delivered'], isNot(true));
      expect(texts(laptop), ['one']);
    });

    test('only the user unblocks, and that clears the key and the id together', () async {
      door
        ..hear(laptop, 'laptop-1')
        ..decide = (_) => false;
      await door.post(laptop, me, 'laptop-1', 'spam');
      // It came back with a new key; the user unblocks it from its card.
      final reinstalled = chatPeer(guest.fingerprint, 'laptop-1', '127.0.0.1');
      door.store.unblock(reinstalled);
      expect(door.store.isBlocked(reinstalled), isFalse);
      expect(door.store.isBlocked(chatPeer(laptop.fingerprint, 'laptop-1', '127.0.0.1')), isFalse);

      door.decide = (_) => true;
      final r = await door.post(laptop, me, 'laptop-1', 'hello');
      expect(r.json['delivered'], isTrue);
      expect(door.asked, hasLength(2), reason: 'unblocked means asked again, never let in');
    });

    test('a block on one device leaves another device at its address alone', () async {
      door
        ..hear(laptop, 'laptop-1')
        ..decide = (_) => false;
      await door.post(laptop, me, 'laptop-1', 'spam');
      door
        ..hear(guest, 'phone-2')
        ..decide = (_) => true;
      final r = await door.post(guest, me, 'phone-2', 'hello');
      expect(r.json['delivered'], isTrue);
      expect(door.store.isBlocked(chatPeer(guest.fingerprint, 'phone-2', '127.0.0.1')), isFalse);
    });
  });

  group('the sender', () {
    test('the token it keeps follows the certificate of the device it writes to', () async {
      final tokens = <String?>[];
      final store = ChatStore(send: (t, d, k) async {
        tokens.add(k);
        return (outcome: ChatOutcome.sent, token: 'issued-to-${d.fingerprint.substring(0, 4)}');
      });
      final there = Device(id: 'laptop-1', name: 'PC', type: 'desktop', ip: '10.0.0.7', port: 1, fingerprint: laptop.fingerprint);
      final moved = there.copyWith(ip: '10.0.0.8');
      final stranger = Device(id: 'phone-2', name: 'Phone', type: 'phone', ip: '10.0.0.7', port: 1, fingerprint: guest.fingerprint);
      await store.write(there, 'one');
      await store.write(moved, 'two');
      await store.write(stranger, 'three');
      expect(tokens, [null, 'issued-to-${laptop.fingerprint.substring(0, 4)}', null]);
      expect(store.thread(there.chatKey)!.messages.map((m) => m.text), ['one', 'two']);
    });
  });
}
