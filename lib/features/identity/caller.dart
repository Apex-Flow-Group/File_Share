import 'dart:io';

import 'fingerprint.dart';

/// Who sent [req]: the fingerprint of the certificate it showed in the TLS
/// handshake. Null when it showed none, and such a request is refused.
String? callerFingerprint(HttpRequest req) {
  final cert = req.certificate;
  return cert == null ? null : fingerprintOf(cert.der);
}

/// The fingerprint discovery heard from device [id] at [address]; null when
/// no such device announced itself. A request whose certificate is another
/// is refused before the user is asked.
typedef ExpectedFingerprint = String? Function(String id, String address);
