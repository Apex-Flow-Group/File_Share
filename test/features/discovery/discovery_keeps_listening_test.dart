import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/protocol/discovery_packet.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seen on a phone: its Wi-Fi dropped, one presence send failed, and Dart
/// closed the socket after reporting the error. The app stayed open but
/// neither sent nor heard anything until it was restarted.

const _me = Device(id: 'me', name: 'This PC', type: 'desktop', ip: '127.0.0.1', port: 40000);

Future<int> _freePort() async {
  final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  s.close();
  return port;
}

Future<void> _announce(int port, {String id = 'phone-1', String name = 'Phone'}) async {
  final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final packet = DiscoveryPacket.encode(
      Device(id: id, name: name, type: 'phone', port: 40100), shareEnabled: false);
  s.send(utf8.encode(packet), InternetAddress.loopbackIPv4, port);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  s.close();
}

/// Sends until the service lists the device, so a socket that is still
/// being reopened gets more than one chance.
Future<Device?> _heard(DiscoveryService svc, int port, {String id = 'phone-1'}) async {
  final found = svc.onDeviceFound.firstWhere((d) => d.id == id);
  for (var i = 0; i < 30; i++) {
    await _announce(port, id: id);
    final d = await found.timeout(const Duration(milliseconds: 100), onTimeout: () => _none);
    if (!identical(d, _none)) {
      return d;
    }
  }
  return null;
}

const _none = Device(id: '', name: '', type: '');

class _Iface implements NetworkInterface {
  _Iface(this.name, List<String> ips)
      : addresses = [for (final ip in ips) InternetAddress(ip)];
  @override
  final String name;
  @override
  final List<InternetAddress> addresses;
  @override
  int get index => 0;
}

void main() {
  late int port;
  late DiscoveryService svc;

  setUp(() async {
    port = await _freePort();
    svc = DiscoveryService(
      port: port,
      interval: const Duration(milliseconds: 100),
      listInterfaces: () async => [],
    );
  });

  tearDown(() => svc.stop());

  test('a presence packet that arrives is listed', () async {
    await svc.start(_me);
    final d = await _heard(svc, port);
    expect(d?.name, 'Phone');
    expect(d?.ip, '127.0.0.1');
  });

  test('after a send fails and closes the socket, the service listens again', () async {
    final unhandled = <Object>[];
    await runZonedGuarded(() async {
      await svc.start(_me);
      final first = svc.debugSocket!;
      // With broadcast off, the next send to 255.255.255.255 fails with a
      // real OS error on Windows and Linux, the same path as a lost network.
      first.broadcastEnabled = false;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(identical(svc.debugSocket, first), isFalse,
          reason: 'the closed socket must be replaced');
      expect(svc.isListening, isTrue);
      expect(await _heard(svc, port), isNotNull);
    }, (e, _) => unhandled.add(e));
    expect(unhandled, isEmpty, reason: 'a failed send is not an unhandled error');
  });

  test('a service that cannot open its port keeps trying and listens once it can', () async {
    // Another program holds the port, so the first bind fails.
    final blocker =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: false);
    try {
      await svc.start(_me);
      expect(svc.isListening, isFalse);
    } finally {
      blocker.close();
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(svc.isListening, isTrue);
    expect(await _heard(svc, port), isNotNull);
  });

  test('refresh opens a new socket and still lists devices', () async {
    await svc.start(_me);
    final first = svc.debugSocket!;
    await svc.restart();
    expect(identical(svc.debugSocket, first), isFalse);
    expect(await _heard(svc, port), isNotNull);
  });

  test('after stop, the socket is not reopened', () async {
    await svc.start(_me);
    await svc.stop();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(svc.isListening, isFalse);
    expect(svc.debugSocket, isNull);
  });

  test('a device on the address we think is ours is still listed (only our id is skipped)',
      () async {
    await svc.start(_me);
    expect(await _heard(svc, port, id: 'other-app-same-pc'), isNotNull);
    expect(await _heard(svc, port, id: 'me'), isNull);
  });

  group('where the presence packet goes', () {
    test('to every network the device is on, read again each time', () {
      final targets = DiscoveryService.broadcastTargets([
        _Iface('Ethernet', ['192.168.8.70']),
        _Iface('Wi-Fi 4', ['192.168.137.1']),
        _Iface('Wi-Fi', ['192.168.8.28']),
        _Iface('vEthernet (WSL)', ['172.17.112.1']),
      ]);
      expect(targets, unorderedEquals([
        '255.255.255.255',
        '192.168.8.255',
        '192.168.137.255',
        '172.17.112.255',
      ]));
    });

    test('not to loopback or link-local addresses', () {
      final targets = DiscoveryService.broadcastTargets([
        _Iface('lo', ['127.0.0.1']),
        _Iface('Wi-Fi 5', ['169.254.220.189']),
      ]);
      expect(targets, ['255.255.255.255']);
    });
  });
}
