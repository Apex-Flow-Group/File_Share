import '../../identity/pin_store.dart';
import 'chat_key.dart';

/// What a block holds: the key and the id the device came with.
typedef ChatBlock = ({ChatKey key, String id});

/// Every block of this run, in memory only, and the one rule that decides
/// whom a block turns away: the chat, the chat door and the file door all
/// ask here.
///
/// The key always blocks. The id alone blocks only a key not pinned for that
/// id: a reinstalled device stays blocked (owner decision), but a device
/// that posed with a colleague's id and was refused does not get the
/// colleague, whose key is pinned, blocked with it.
class BlockList {
  /// Without [pins] no key is pinned, so the id alone always blocks.
  BlockList([this._pins]);

  final PinStore? _pins;
  final _blocks = <ChatBlock>{};

  bool isBlocked(ChatPeer peer) => _blocks.any((b) => _turnsAway(b, peer));

  void block(ChatPeer peer) => _blocks.add((key: peer.key, id: peer.id));

  /// Lifts only what turns [peer] away, so unblocking a colleague leaves the
  /// block on a device that took its id.
  void unblock(ChatPeer peer) => _blocks.removeWhere((b) => _turnsAway(b, peer));

  bool _turnsAway(ChatBlock b, ChatPeer peer) =>
      b.key == peer.key || (b.id == peer.id && _pins?.pinned(peer.id) != peer.key.fingerprint);
}
