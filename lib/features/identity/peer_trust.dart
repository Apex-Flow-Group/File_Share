import 'dart:io';

import 'fingerprint.dart';
import 'self_signed.dart';

/// The server's list of client certificates it lets finish the handshake.
///
/// dart:io has no callback on the server side: a client certificate it does
/// not trust fails the handshake. So every certificate heard in discovery is
/// added here, and the doors then check the fingerprint against the device
/// the request claims to be. Being listed here trusts nobody by itself.
class PeerTrust {
  PeerTrust(this._context, {this.limit = 4096});

  final SecurityContext _context;

  /// A store that only grows: a flood of made-up packets must not fill memory.
  /// Past the limit, a new device can connect after the app restarts.
  final int limit;
  final _added = <String>{};

  /// True when [certificate] (DER) can now finish a handshake.
  bool trust(List<int> certificate) {
    final fp = fingerprintOf(certificate);
    if (_added.contains(fp)) {
      return true;
    }
    if (_added.length >= limit) {
      return false;
    }
    try {
      _context.setTrustedCertificatesBytes(toPem('CERTIFICATE', certificate).codeUnits);
    } on TlsException {
      return false;
    }
    _added.add(fp);
    return true;
  }
}
