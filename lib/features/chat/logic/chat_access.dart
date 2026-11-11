import 'dart:convert';
import 'dart:math';

import 'chat_key.dart';

class ChatGrant {
  ChatGrant(this.key, this.name);
  final ChatKey key;

  /// The name the device gave when the user agreed, already cleaned.
  final String name;
}

/// Who may chat: a device the user agreed to gets a token bound to its real
/// address and to the id it gave, kept in memory only, so closing the app
/// ends every agreement.
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
  final _blocked = <ChatKey>{};
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

  String admit(ChatKey key, String name) {
    _blocked.remove(key);
    _unanswered.remove(key);
    String token;
    do {
      token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));
    } while (_grants.containsKey(token));
    _grants[token] = ChatGrant(key, name);
    return token;
  }

  /// Null for a missing or unknown token, or one sent from another address
  /// or with another id than it was issued for.
  ChatGrant? check(String? token, ChatKey key) {
    final grant = _grants[token];
    return grant == null || grant.key != key ? null : grant;
  }

  /// Owner decision: refusing the question, or the block button, blocks the
  /// device until the user unblocks it or the app closes. Its token stops
  /// working and it is not asked about, so a stranger cannot keep asking.
  void block(ChatKey key) {
    _grants.removeWhere((_, g) => g.key == key);
    _blocked.add(key);
  }

  /// Back to a device never seen: its next message asks the user again,
  /// since whoever holds that address now may not be the device it was.
  void unblock(ChatKey key) {
    _blocked.remove(key);
    _unanswered.remove(key);
  }

  bool isBlocked(ChatKey key) => _blocked.contains(key);
}
