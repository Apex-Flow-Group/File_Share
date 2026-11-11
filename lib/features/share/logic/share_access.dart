import 'dart:convert';
import 'dart:math';

class ShareGrant {
  ShareGrant(this.address, this.fingerprint, this.name, this.uploads, this.lastUse);
  final String address;

  /// The certificate the device held when the user agreed.
  final String fingerprint;

  /// The name the device gave when the user agreed, already cleaned.
  final String name;

  /// Whether the question the user answered included uploading.
  final bool uploads;
  DateTime lastUse;
}

/// Who may open the shared folder: a device the user agreed to gets a token
/// bound to its real address and its certificate. Turning the folder off ends
/// every token.
class ShareAccess {
  ShareAccess({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  /// Browsing a folder has pauses longer than a file transfer's.
  static const idleLimit = Duration(minutes: 30);

  final Random _random;
  final DateTime Function() _clock;
  final _grants = <String, ShareGrant>{};

  String admit(String address, String name, String fingerprint, {bool uploads = false}) {
    _dropExpired();
    String token;
    do {
      token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));
    } while (_grants.containsKey(token));
    _grants[token] = ShareGrant(address, fingerprint, name, uploads, _clock());
    return token;
  }

  /// Null for a missing, unknown or expired token, or one sent from another
  /// address or certificate.
  ShareGrant? check(String? token, String address, String fingerprint) {
    final grant = _grants[token];
    if (grant == null || grant.address != address || grant.fingerprint != fingerprint) {
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
