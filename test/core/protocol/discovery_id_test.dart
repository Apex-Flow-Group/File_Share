import 'dart:convert';

import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/discovery_packet.dart';
import 'package:apex_file_share/core/text/clean_label.dart';
import 'package:apex_file_share/features/identity/fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Any bytes: discovery only checks that the fingerprint is of them.
const _cert = [1, 2, 3];

String _packet(String id) => '${DiscoveryPacket.magic}${jsonEncode({
      'version': ApexProtocol.version,
      'id': id,
      'name': 'PC',
      'type': 'desktop',
      'port': 4000,
      'fp': fingerprintOf(_cert),
      'cert': base64.encode(_cert),
    })}';

void main() {
  test('the id from discovery is cleaned as the chat door cleans it, so both are one key', () {
    final raw = String.fromCharCodes([...'pc'.codeUnits, 0x202E, 0x0A, ...'1'.codeUnits]);
    final d = DiscoveryPacket.decode(_packet(raw), from: '10.0.0.7', selfId: 'me')!;
    expect(d.id, cleanDeviceId(raw));
    expect(d.id.runes.any((r) => r < 0x20 || r == 0x202E), isFalse);
  });

  test('an id that is nothing once cleaned is not a device', () {
    final blank = String.fromCharCodes([0x200B, 0x202E]);
    expect(DiscoveryPacket.decode(_packet(blank), from: '10.0.0.7', selfId: 'me'), isNull);
  });
}
