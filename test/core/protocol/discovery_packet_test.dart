import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/discovery_packet.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(
    id: 'pc-1', name: 'Office PC', type: 'desktop', ip: '192.168.1.5', port: 40100, hostname: 'office');

String _raw(Map<String, Object?> body) => '${DiscoveryPacket.magic}${jsonEncode(body)}';

Map<String, Object?> _body([Map<String, Object?> change = const {}]) => {
      'version': ApexProtocol.version,
      'id': 'pc-1',
      'name': 'Office PC',
      'type': 'desktop',
      'port': 40100,
      ...change,
    };

void main() {
  test('a packet carries the protocol version and reads back', () {
    final text = DiscoveryPacket.encode(_pc, shareEnabled: true);
    final json = jsonDecode(text.substring(DiscoveryPacket.magic.length)) as Map;
    expect(json['version'], ApexProtocol.version);

    final d = DiscoveryPacket.decode(text, from: '192.168.1.5', selfId: 'me')!;
    expect([d.id, d.name, d.type, d.port, d.hostname, d.shareEnabled],
        ['pc-1', 'Office PC', 'desktop', 40100, 'office', true]);
  });

  test('a packet with no version or another version is ignored', () {
    for (final v in [null, ApexProtocol.version - 1, ApexProtocol.version + 1, '${ApexProtocol.version}']) {
      final body = _body({'version': v})..removeWhere((k, value) => k == 'version' && value == null);
      expect(DiscoveryPacket.decode(_raw(body), from: '192.168.1.5', selfId: 'me'), isNull,
          reason: 'version $v');
    }
  });

  test('the address comes from the datagram, never from the packet', () {
    final d = DiscoveryPacket.decode(_raw(_body({'ip': '10.0.0.99'})), from: '192.168.1.5', selfId: 'me');
    expect(d!.ip, '192.168.1.5');
  });

  test('our own packet is ignored', () {
    expect(DiscoveryPacket.decode(_raw(_body()), from: '192.168.1.5', selfId: 'pc-1'), isNull);
  });

  test('a broken packet is ignored', () {
    for (final raw in [
      'HELLO${jsonEncode(_body())}',
      '${DiscoveryPacket.magic}{not json',
      '${DiscoveryPacket.magic}[1,2]',
      _raw(_body({'id': null})),
      _raw(_body({'id': ''})),
      _raw(_body({'name': 5})),
      _raw(_body({'port': '40100'})),
      _raw(_body({'port': 0})),
      _raw(_body({'port': 70000})),
    ]) {
      expect(DiscoveryPacket.decode(raw, from: '192.168.1.5', selfId: 'me'), isNull, reason: raw);
    }
  });

  test('the shown name and host name are cleaned', () {
    final d = DiscoveryPacket.decode(
        _raw(_body({'name': 'Boss${String.fromCharCode(0x202E)}\nPC', 'hostname': 'h${String.fromCharCode(7)}x'})),
        from: '192.168.1.5',
        selfId: 'me');
    expect(d!.name, 'Boss PC');
    expect(d.hostname, 'h x');
  });

  test('the discovery service reads and writes packets only through DiscoveryPacket', () {
    final src = File('lib/services/discovery_service.dart').readAsStringSync();
    expect(src, contains('DiscoveryPacket.decode('));
    expect(src, contains('DiscoveryPacket.encode('));
    expect(src.contains('jsonDecode(') || src.contains('jsonEncode('), isFalse,
        reason: 'A second reader or writer would skip the version check.');
  });

  test('Nearby discovery is split by protocol version too', () {
    final src = File('lib/services/discovery_service.dart').readAsStringSync();
    expect(src, contains('DiscoveryPacket.nearbyServiceId'));
    expect(DiscoveryPacket.nearbyServiceId, endsWith('.v${ApexProtocol.version}'));
  });
}
