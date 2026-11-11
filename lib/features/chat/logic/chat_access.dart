import 'dart:convert';
import 'dart:math';

import 'chat_key.dart';

class ChatGrant {
  ChatGrant(this.key, this.id, this.name);

  /// The certificate the device held when the user agreed.
  final ChatKey key;

  /// The id it gave then: blocking that id ends this grant too.
  final String id;

  /// The name the device gave when the user agreed, already cleaned.
  final String name;
}

/// Who may chat: a device the user agreed to gets a token bound to its
/// certificate, kept in memory only, so closing the app ends every agreement.
/// The address is not part of it: the same device back at a new address
/// still holds its certificate.
class ChatAccess {
  ChatAccess({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  /// After a question nobody answered, the same device is not asked again
  /// for this long: otherwise it could raise one every 30 seconds forever,
  /// and every file offer meanwhile would be turned away as busy.
  static const quietAfterNoAnswer = Duration(minutes: 2);

  final Random _random;
  final DateTime Function() _clock;
  final _grants = <String, ChatGrant>{};
  final _blocked = <ChatBlock>{};
  final _unanswered = <ChatKey, DateTime>{};

  void unanswered(ChatKey key) => _unanswered[key] = _clock();

  bool isQuiet(ChatKey key) {
    final since = _unanswered[key];
    if (since == null) {
      return false;
    }
    if (_clock().difference(since) >= quietAfterNoAnswer) {
      _unanswered.remove(key);
      return false;
    }
    return true;
  }

  String admit(ChatPeer peer, String name) {
    _blocked.removeWhere((b) => blocks(b, peer));
    _unanswered.remove(peer.key);
    String token;
    do {
      token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));
    } while (_grants.containsKey(token));
    _grants[token] = ChatGrant(peer.key, peer.id, name);
    return token;
  }

  /// Null for a missing or unknown token, or one sent with another
  /// certificate than it was issued for.
  ChatGrant? check(String? token, ChatKey key) {
    final grant = _grants[token];
    return grant == null || grant.key != key ? null : grant;
  }

  /// Owner decision: refusing the question, or the block button, blocks the
  /// device until the user unblocks it or the app closes. Its token stops
  /// working and it is not asked about, so a stranger cannot keep asking.
  /// Both its key and its id are blocked: a new key alone does not lift it.
  void block(ChatPeer peer) {
    _grants.removeWhere((_, g) => g.key == peer.key || g.id == peer.id);
    _blocked.add((key: peer.key, id: peer.id));
  }

  /// Back to a device never seen: its next message asks the user again,
  /// since whoever holds that id now may not be the device it was. Lifts
  /// every block that matches it, by key or by id.
  void unblock(ChatPeer peer) {
    _blocked.removeWhere((b) => blocks(b, peer));
    _unanswered.remove(peer.key);
  }

  bool isBlocked(ChatPeer peer) => _blocked.any((b) => blocks(b, peer));
}
