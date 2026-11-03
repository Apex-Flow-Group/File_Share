import 'dart:convert';
import 'dart:math';

class ShareGrant {
  ShareGrant(this.address, this.name, this.lastUse);
  final String address;

  /// The name the device gave when the user agreed, already cleaned.
  final String name;
  DateTime lastUse;
}

/// Who may open the shared folder: a device the user agreed to gets a token
/// bound to its real address. Turning the folder off ends every token.
class ShareAccess {
  ShareAccess({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  /// Browsing a folder has pauses longer than a file transfer's.
  static const idleLimit = Duration(minutes: 30);

  final Random _random;
  final DateTime Function() _clock;
  final _grants = <String, ShareGrant>{};

  String admit(String address, String name) {
    _dropExpired();
    String token;
    do {
      token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));
    } while (_grants.containsKey(token));
    _grants[token] = ShareGrant(address, name, _clock());
    return token;
  }

  /// Null for a missing, unknown or expired token, or one sent from another address.
  ShareGrant? check(String? token, String address) {
    final grant = _grants[token];
    if (grant == null || grant.address != address) {
      return null;
    }
    if (_clock().difference(grant.lastUse) > idleLimit) {
      _grants.remove(token);
      return null;
    }
    grant.lastUse = _clock();
    return grant;
  }

  void revokeAll() => _grants.clear();

  void _dropExpired() =>
      _grants.removeWhere((_, g) => _clock().difference(g.lastUse) > idleLimit);
}
