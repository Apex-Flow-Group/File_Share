import 'dart:convert';
import 'dart:math';

class ChatGrant {
  ChatGrant(this.address, this.name);
  final String address;

  /// The name the device gave when the user agreed, already cleaned.
  final String name;
}

/// Who may chat: a device the user agreed to gets a token bound to its real
/// address, kept in memory only, so closing the app ends every agreement.
class ChatAccess {
  ChatAccess({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  /// After a question nobody answered, the same address is not asked again
  /// for this long: otherwise it could raise one every 30 seconds forever,
  /// and every file offer meanwhile would be turned away as busy.
  static const quietAfterNoAnswer = Duration(minutes: 2);

  final Random _random;
  final DateTime Function() _clock;
  final _grants = <String, ChatGrant>{};
  final _declined = <String>{};
  final _unanswered = <String, DateTime>{};

  void unanswered(String address) => _unanswered[address] = _clock();

  bool isQuiet(String address) {
    final since = _unanswered[address];
    if (since == null) {
      return false;
    }
    if (_clock().difference(since) >= quietAfterNoAnswer) {
      _unanswered.remove(address);
      return false;
    }
    return true;
  }

  String admit(String address, String name) {
    _declined.remove(address);
    _unanswered.remove(address);
    String token;
    do {
      token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));
    } while (_grants.containsKey(token));
    _grants[token] = ChatGrant(address, name);
    return token;
  }

  /// Null for a missing or unknown token, or one sent from another address.
  ChatGrant? check(String? token, String address) {
    final grant = _grants[token];
    return grant == null || grant.address != address ? null : grant;
  }

  /// Proposal awaiting the owner: a refused device is not asked about again
  /// until the app closes, so a stranger cannot keep raising the question.
  void decline(String address) => _declined.add(address);

  bool isDeclined(String address) => _declined.contains(address);
}
