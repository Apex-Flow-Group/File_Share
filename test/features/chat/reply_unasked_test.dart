import 'package:apex_file_share/features/chat/logic/chat_access.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writing is agreeing (owner decision): a device this user wrote to and
/// reached replies without "accept chat?", at the certificate reached.
final _key = 'a' * 64;
final _other = 'b' * 64;

void main() {
  test('a device written to and reached replies with no token', () {
    final access = ChatAccess();
    access.wrote(chatPeer(_key, 'pc', '10.0.0.7'), 'Office PC');
    final grant = access.check(null, ChatKey(_key));
    expect(grant, isNotNull);
    expect(grant!.name, 'Office PC');
  });

  test('another certificate, even with the same id, is still asked', () {
    final access = ChatAccess();
    access.wrote(chatPeer(_key, 'pc', '10.0.0.7'), 'Office PC');
    expect(access.check(null, ChatKey(_other)), isNull);
  });

  test('a device without a certificate is still asked', () {
    final access = ChatAccess();
    final unverified = (key: ChatKey.unverified('pc', '10.0.0.7'), id: 'pc', address: '10.0.0.7');
    access.wrote(unverified, 'Office PC');
    expect(access.check(null, unverified.key), isNull);
  });

  test('a block ends it, and unblocking does not bring it back', () {
    final access = ChatAccess();
    final peer = chatPeer(_key, 'pc', '10.0.0.7');
    access.wrote(peer, 'Office PC');
    access.block(peer);
    expect(access.check(null, ChatKey(_key)), isNull);
    access.unblock(peer);
    expect(access.check(null, ChatKey(_key)), isNull, reason: 'back as a new device');
  });

  test('only a message that arrived counts as writing to it', () async {
    final reached = <ChatPeer>[];
    var outcome = ChatOutcome.declined;
    final store = ChatStore(
      send: (t, d, k) async => (outcome: outcome, token: null),
      onReached: (peer, name) => reached.add(peer),
    );
    final pc = Device(id: 'pc', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', fingerprint: _key);
    await store.write(pc, 'hello');
    expect(reached, isEmpty);
    outcome = ChatOutcome.sent;
    await store.write(pc, 'hello again');
    expect(reached.single.key, ChatKey(_key));
  });
}
