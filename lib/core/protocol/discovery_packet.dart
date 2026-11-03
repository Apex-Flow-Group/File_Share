import 'dart:convert';

import '../../models/device.dart';
import '../text/clean_label.dart';
import 'apex_protocol.dart';

/// The one reader and writer of the UDP presence packet. A packet with no
/// version or another version is ignored, so a copy that speaks another
/// protocol never appears in the device list.
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
    final id = json['id'];
    final name = json['name'];
    final port = json['port'];
    if (id is! String || id.isEmpty || id == selfId || name is! String) {
      return null;
    }
    if (port is! int || port < 1 || port > 65535) {
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
    );
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
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || id == selfId || name is! String) {
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
