@TestOn('vm')
library;

import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';
import 'chat_door.dart';

/// A block holds a key and an id. The key always blocks; the id alone blocks
/// only a key not pinned for that id, so a device posing with a colleague's
/// id cannot get the colleague blocked, and a blocked device that reinstalls
/// stays blocked (owner decision). Real TLS on 127.0.0.1.
void main() {
  late TlsPeer me;
  late TlsPeer colleague;
  late TlsPeer reinstalled;
  late TlsPeer impostor;
  late ChatDoor door;

  setUpAll(() async {
    me = await TlsPeer.create();
    colleague = await TlsPeer.create();
    reinstalled = await TlsPeer.create();
    impostor = await TlsPeer.create();
  });

  setUp(() async => door = await ChatDoor.start(me, [colleague, reinstalled, impostor]));
  tearDown(() => door.stop());

  ChatPeer colleagueAt(String fp) => chatPeer(fp, 'laptop-1', '127.0.0.1');

  /// The colleague writes first and is accepted: its key is pinned for its id.
  Future<String> accepted() async {
    door.hear(colleague, 'laptop-1');
    final r = await door.post(colleague, me, 'laptop-1', 'hello');
    expect(r.json['delivered'], isTrue);
    expect(door.pins.pinned('laptop-1'), colleague.fingerprint);
    return r.json['token'] as String;
  }

  /// A device with its own key announces the colleague's id from another
  /// address, and the user refuses it.
  Future<void> impostorRefused() async {
    door
      ..hear(impostor, 'laptop-1', address: '127.0.0.2')
      ..decide = (_) => false;
    final r = await door.post(impostor, me, 'laptop-1', 'hi, it is me', address: '127.0.0.2');
    expect(r.json['accepted'], isFalse);
    door.decide = (_) => true;
  }

  test('refusing a device that took a colleague\'s id leaves the colleague, pinned, unblocked', () async {
    final token = await accepted();
    await impostorRefused();

    expect(door.store.isBlocked(colleagueAt(colleague.fingerprint)), isFalse);
    final r = await door.post(colleague, me, 'laptop-1', 'still me', token: token);
    expect(r.json['delivered'], isTrue, reason: 'its token still works: it was never blocked');
    expect(door.asked, hasLength(2), reason: 'asked about the colleague once and the impostor once');
    expect(door.store.isBlocked(chatPeer(impostor.fingerprint, 'laptop-1', '127.0.0.2')), isTrue);
  });

  test('a blocked colleague that comes back with a new key is still blocked, and not asked about', () async {
    await accepted();
    door.store.block(colleagueAt(colleague.fingerprint));

    // Reinstalled: a new certificate, the same id.
    door.hear(reinstalled, 'laptop-1');
    final r = await door.post(reinstalled, me, 'laptop-1', 'let me in');
    expect(r.json['accepted'], isFalse);
    expect(door.asked, hasLength(1));
    expect(door.store.isBlocked(colleagueAt(reinstalled.fingerprint)), isTrue);
  });

  test('unblocking the colleague does not lift the impostor\'s block', () async {
    await accepted();
    await impostorRefused();
    door.store
      ..block(colleagueAt(colleague.fingerprint))
      ..unblock(colleagueAt(colleague.fingerprint));

    expect(door.store.isBlocked(chatPeer(impostor.fingerprint, 'laptop-1', '127.0.0.2')), isTrue);
    final r = await door.post(impostor, me, 'laptop-1', 'again', address: '127.0.0.2');
    expect(r.json['accepted'], isFalse);
    expect(door.asked, hasLength(2), reason: 'the impostor is not asked about again');

    final back = await door.post(colleague, me, 'laptop-1', 'back');
    expect(back.json['delivered'], isTrue);
    expect(door.asked, hasLength(3), reason: 'unblocked means asked again, never let in');
  });
}
