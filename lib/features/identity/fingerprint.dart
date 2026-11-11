import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

/// A device's identity: SHA-256 of its certificate (DER), lowercase hex.
String fingerprintOf(List<int> der) {
  final digest = SHA256Digest().process(Uint8List.fromList(der));
  final out = StringBuffer();
  for (final b in digest) {
    out.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

final _fingerprint = RegExp(r'^[0-9a-f]{64}$');

bool isFingerprint(Object? value) => value is String && _fingerprint.hasMatch(value);
