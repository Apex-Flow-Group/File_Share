import 'dart:io';
import 'dart:typed_data';

import '../../platform/owner_only.dart';
import 'fingerprint.dart';
import 'self_signed.dart';

/// This install's key and certificate, made once on first run and read back
/// on every later one. Other devices know this device by [fingerprint].
class DeviceIdentity {
  DeviceIdentity._(this.certificate, this._certificatePem, this._keyPem)
      : fingerprint = fingerprintOf(certificate);

  final Uint8List certificate;
  final String fingerprint;
  final String _certificatePem;
  final String _keyPem;

  static const certificateFile = 'identity.crt';
  static const keyFile = 'identity.key';

  /// The identity kept in [folder], made there when it has none. A folder
  /// whose files cannot be read gets a new identity, and peers see a new key
  /// instead of the app failing to start.
  static Future<DeviceIdentity> loadOrCreate(Directory folder) async {
    final existing = await _load(folder);
    if (existing != null) {
      return existing;
    }
    await folder.create(recursive: true);
    await keepOwnerOnly(folder);
    final made = createSelfSigned();
    final keyPem = toPem('EC PRIVATE KEY', made.privateKey);
    final certPem = toPem('CERTIFICATE', made.certificate);
    // The key first: a certificate on disk without its key is never read.
    await _write(File('${folder.path}/$keyFile'), keyPem);
    await _write(File('${folder.path}/$certificateFile'), certPem);
    return DeviceIdentity._(made.certificate, certPem, keyPem);
  }

  static Future<DeviceIdentity?> _load(Directory folder) async {
    final cert = File('${folder.path}/$certificateFile');
    final key = File('${folder.path}/$keyFile');
    try {
      if (!await cert.exists() || !await key.exists()) {
        return null;
      }
      final certPem = await cert.readAsString();
      final keyPem = await key.readAsString();
      final der = fromPem('CERTIFICATE', certPem);
      if (der == null) {
        return null;
      }
      final identity = DeviceIdentity._(der, certPem, keyPem);
      // Throws when the key does not belong to the certificate.
      identity.clientContext();
      return identity;
    } on Exception {
      return null;
    } on ArgumentError {
      // What SecurityContext throws for a file with no key in it.
      return null;
    }
  }

  static Future<void> _write(File file, String text) async {
    final part = File('${file.path}.part');
    await part.writeAsString(text, flush: true);
    await keepOwnerOnly(part);
    await part.rename(file.path);
  }

  /// For the server: shows this certificate and asks every client for its
  /// own. A client's certificate is accepted only once [PeerTrust] added it.
  SecurityContext serverContext() => _context();

  /// For requests to other devices: shows this certificate. It trusts no
  /// server by itself; each request checks the server's fingerprint.
  SecurityContext clientContext() => _context();

  SecurityContext _context() => SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(_certificatePem.codeUnits)
    ..usePrivateKeyBytes(_keyPem.codeUnits);
}
