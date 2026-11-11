import 'dart:convert';

import '../../features/identity/fingerprint.dart';
import '../../models/device.dart';
import '../text/clean_label.dart';
import 'apex_protocol.dart';

/// The one reader and writer of the UDP presence packet. A packet with no
/// version or another version is ignored, so a copy that speaks another
/// protocol never appears in the device list. Nor does one without its
/// certificate and the fingerprint of it: no request could reach it.
class DiscoveryPacket {
  DiscoveryPacket._();

  static const magic = 'APEX3:';

  /// Nearby finds only phones that advertise the same id, so the version
  /// keeps other protocols out of the list there too.
  static const nearbyServiceId = 'com.apexflow.tools.transfer.v${ApexProtocol.version}';

  static String encode(Device d, {required bool shareEnabled}) => '$magic${jsonEncode({
        'version': ApexProtocol.version,
        'id': d.id,
        'name': d.name,
        'type': d.type,
        'port': d.port,
        'fp': d.fingerprint,
        'cert': base64.encode(d.certificate ?? const []),
        if (d.hostname != null && d.hostname!.isNotEmpty) 'hostname': d.hostname,
        if (shareEnabled) 'share': true,
      })}';

  /// [from] is the datagram's source address; any address in the packet is
  /// ignored. Null for our own packet or anything malformed.
  static Device? decode(String text, {required String from, required String selfId}) {
    if (!text.startsWith(magic)) {
      return null;
    }
    final Object? json;
    try {
      json = jsonDecode(text.substring(magic.length));
    } on FormatException {
      return null;
    }
    if (json is! Map || json['version'] != ApexProtocol.version) {
      return null;
    }
    // Cleaned as the chat and offer doors clean it, so the card and the
    // chat it opens are under one key.
    final id = cleanDeviceId(json['id']);
    final name = json['name'];
    final port = json['port'];
    if (id == null || id == selfId || name is! String) {
      return null;
    }
    if (port is! int || port < 1 || port > 65535) {
      return null;
    }
    final certificate = _certificate(json['cert']);
    final fp = json['fp'];
    if (!isFingerprint(fp) || certificate == null || fingerprintOf(certificate) != fp) {
      return null;
    }
    final type = json['type'];
    final hostname = json['hostname'];
    final shown = cleanLabel(name);
    return Device(
      id: id,
      name: shown.isEmpty ? from : shown,
      type: type is String ? cleanLabel(type) : 'desktop',
      ip: from,
      port: port,
      hostname: hostname is String ? cleanLabel(hostname) : null,
      shareEnabled: json['share'] == true,
      lastSeen: DateTime.now(),
      fingerprint: fp as String,
      certificate: certificate,
    );
  }

  /// A P-256 certificate is a few hundred bytes; the limit keeps a made-up
  /// one from growing the packet or the server's trust list.
  static const _certificateLimit = 2048;

  static List<int>? _certificate(Object? value) {
    if (value is! String || value.length > _certificateLimit * 4 ~/ 3 + 4) {
      return null;
    }
    try {
      final der = base64.decode(value);
      return der.isEmpty || der.length > _certificateLimit ? null : der;
    } on FormatException {
      return null;
    }
  }

  /// A device on another version, or one so old its packet has no version:
  /// shown disabled with the name and address as received, with no port and
  /// no shared folder, so nothing can reach it. Null for a current packet
  /// (read it with [decode]), our own, or anything malformed.
  static Device? otherVersion(String text, {required String from, required String selfId}) {
    if (!text.startsWith(magic)) {
      return null;
    }
    final Object? json;
    try {
      json = jsonDecode(text.substring(magic.length));
    } on FormatException {
      return null;
    }
    if (json is! Map || json['version'] == ApexProtocol.version) {
      return null;
    }
    final id = cleanDeviceId(json['id']);
    final name = json['name'];
    if (id == null || id == selfId || name is! String) {
      return null;
    }
    final type = json['type'];
    final shown = cleanLabel(name);
    return Device(
      id: id,
      name: shown.isEmpty ? from : shown,
      type: type is String ? cleanLabel(type) : 'desktop',
      ip: from,
      versionMismatch: true,
      lastSeen: DateTime.now(),
    );
  }
}
