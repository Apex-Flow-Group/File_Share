import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// A new EC P-256 key and a self-signed X.509 certificate for it, both DER.
/// The certificate proves nothing by itself: peers trust its fingerprint
/// once their user accepted the device, never its name or its issuer.
({Uint8List certificate, Uint8List privateKey}) createSelfSigned({DateTime? now}) {
  final domain = ECDomainParameters('prime256v1');
  final seed = Random.secure();
  final random = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => seed.nextInt(256)))));
  final generator = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), random));
  final pair = generator.generateKeyPair();
  final public = pair.publicKey as ECPublicKey;
  final private = pair.privateKey as ECPrivateKey;
  final point = public.Q!.getEncoded(false);

  final start = (now ?? DateTime.now()).toUtc().subtract(const Duration(days: 1));
  // A name of its own: the server finds a trusted certificate by its name,
  // and with two of one name it checks the client against the wrong one.
  final unique = [for (var i = 0; i < 16; i++) seed.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  final name = _seq([
    _set([
      _seq([_oid(_commonName), _utf8('Apex File Share $unique')]),
    ]),
  ]);
  final tbs = _seq([
    _tagged(0xa0, _int(BigInt.two)), // v3
    _int(_serial(seed)),
    _seq([_oid(_ecdsaSha256)]),
    name,
    // 99 years: nobody renews this certificate, and its expiry would only
    // break every pin at once.
    _seq([_time(start), _time(DateTime.utc(start.year + 99, start.month, start.day))]),
    name,
    _seq([
      _seq([_oid(_ecPublicKey), _oid(_prime256v1)]),
      _bits(point),
    ]),
  ]);

  // Deterministic k (RFC 6979): no random number to get wrong while signing.
  final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
    ..init(true, PrivateKeyParameter<ECPrivateKey>(private));
  final signature = signer.generateSignature(tbs) as ECSignature;
  final certificate = _seq([
    tbs,
    _seq([_oid(_ecdsaSha256)]),
    _bits(_seq([_int(signature.r), _int(signature.s)])),
  ]);

  // SEC 1 ECPrivateKey, which BoringSSL reads as "EC PRIVATE KEY".
  final privateKey = _seq([
    _int(BigInt.one),
    _octets(_unsigned(private.d!, 32)),
    _tagged(0xa0, _oid(_prime256v1)),
    _tagged(0xa1, _bits(point)),
  ]);
  return (certificate: certificate, privateKey: privateKey);
}

String toPem(String label, List<int> der) {
  final text = base64.encode(der);
  final out = StringBuffer('-----BEGIN $label-----\n');
  for (var i = 0; i < text.length; i += 64) {
    out
      ..write(text.substring(i, min(i + 64, text.length)))
      ..write('\n');
  }
  out.write('-----END $label-----\n');
  return out.toString();
}

/// The DER inside the first [label] block of [pem]; null when there is none.
Uint8List? fromPem(String label, String pem) {
  final match = RegExp('-----BEGIN $label-----([A-Za-z0-9+/=\\s]+)-----END $label-----').firstMatch(pem);
  if (match == null) {
    return null;
  }
  try {
    return base64.decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
  } on FormatException {
    return null;
  }
}

const _commonName = [2, 5, 4, 3];
const _ecPublicKey = [1, 2, 840, 10045, 2, 1];
const _prime256v1 = [1, 2, 840, 10045, 3, 1, 7];
const _ecdsaSha256 = [1, 2, 840, 10045, 4, 3, 2];

BigInt _serial(Random seed) {
  var n = BigInt.zero;
  for (var i = 0; i < 16; i++) {
    n = (n << 8) | BigInt.from(seed.nextInt(256));
  }
  // Positive and never zero.
  return (n >> 1) + BigInt.one;
}

Uint8List _tlv(int tag, List<int> body) {
  final n = body.length;
  final List<int> length;
  if (n < 0x80) {
    length = [n];
  } else {
    final bytes = <int>[];
    for (var v = n; v > 0; v >>= 8) {
      bytes.insert(0, v & 0xff);
    }
    length = [0x80 | bytes.length, ...bytes];
  }
  return Uint8List.fromList([tag, ...length, ...body]);
}

Uint8List _seq(List<List<int>> parts) => _tlv(0x30, [for (final p in parts) ...p]);

Uint8List _set(List<List<int>> parts) => _tlv(0x31, [for (final p in parts) ...p]);

Uint8List _tagged(int tag, List<int> inner) => _tlv(tag, inner);

Uint8List _octets(List<int> bytes) => _tlv(0x04, bytes);

Uint8List _bits(List<int> bytes) => _tlv(0x03, [0, ...bytes]);

Uint8List _utf8(String text) => _tlv(0x0c, utf8.encode(text));

Uint8List _int(BigInt value) {
  final bytes = <int>[];
  var v = value;
  do {
    bytes.insert(0, (v & BigInt.from(0xff)).toInt());
    v >>= 8;
  } while (v > BigInt.zero);
  // A set top bit would read as negative.
  if (bytes.first & 0x80 != 0) {
    bytes.insert(0, 0);
  }
  return _tlv(0x02, bytes);
}

Uint8List _unsigned(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  return out;
}

Uint8List _oid(List<int> arcs) {
  final body = <int>[arcs[0] * 40 + arcs[1]];
  for (final arc in arcs.skip(2)) {
    final chunk = <int>[arc & 0x7f];
    for (var v = arc >> 7; v > 0; v >>= 7) {
      chunk.insert(0, 0x80 | (v & 0x7f));
    }
    body.addAll(chunk);
  }
  return _tlv(0x06, body);
}

/// UTCTime until 2049, GeneralizedTime after, as RFC 5280 requires.
Uint8List _time(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final rest = '${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  if (t.year < 2050) {
    return _tlv(0x17, ascii.encode('${two(t.year % 100)}$rest'));
  }
  return _tlv(0x18, ascii.encode('${t.year}$rest'));
}
