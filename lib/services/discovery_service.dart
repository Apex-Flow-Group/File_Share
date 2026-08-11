// ignore_for_file: always_put_control_body_on_new_line

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../core/apex_core.dart';
import '../models/device.dart';
import '../utils/apex_logger.dart';

class DiscoveryService {
  final _deviceFoundController = StreamController<Device>.broadcast();
  final _deviceLostController = StreamController<String>.broadcast();

  Stream<Device> get onDeviceFound => _deviceFoundController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  // Nearby (Android phone ↔ phone)
  bool _nearbyAdvertising = false;
  bool _nearbyDiscovering = false;

  // UDP broadcast (Desktop ↔ Desktop and Desktop ↔ Android)
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;
  Device? _localDevice;
  static const int _udpPort = 45679;
  static const String _magic = 'APEX3:';

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> start(Device localDevice) async {
    _localDevice = localDevice;
    // Always start UDP so Android can talk to PC and vice versa
    await _startUdp(localDevice);
    if (_isAndroid) {
      await _startNearby(localDevice);
    }
  }

  /// بث فوري متعدد — يُستخدم عند الضغط على refresh
  /// يرسل 3 باكتات بفاصل 300ms لتقليل احتمال الضياع
  void forceBroadcast() {
    _broadcast();
    Future.delayed(const Duration(milliseconds: 300), _broadcast);
    Future.delayed(const Duration(milliseconds: 700), _broadcast);
  }

  /// إرسال unicast مباشر لـ IP جهاز محدد (للأجهزة المثبتة)
  void pingDevice(Device device) {
    final d = _localDevice;
    if (d == null || _udpSocket == null || device.ip.isEmpty) return;
    final msg = '$_magic${jsonEncode({
          'id': d.id,
          'name': d.name,
          'type': d.type,
          'port': d.port,
        })}';
    final data = utf8.encode(msg);
    try {
      _udpSocket!.send(data, InternetAddress(device.ip), _udpPort);
    } catch (_) {}
  }

  // ─── UDP Broadcast (works on all platforms) ───────────────────────────────

  Future<void> _startUdp(Device localDevice) async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, _udpPort,
          reuseAddress: true, reusePort: false);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.multicastHops = 128;

      _udpSocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _udpSocket!.receive();
        if (dg == null) return;
        try {
          final msg = utf8.decode(dg.data);
          if (!msg.startsWith(_magic)) return;
          final json =
              jsonDecode(msg.substring(_magic.length)) as Map<String, dynamic>;
          final id = json['id'] as String;
          if (id == localDevice.id) return; // ignore self by id
          if (dg.address.address == localDevice.ip) return; // ignore self by IP
          _deviceFoundController.add(Device(
            id: id,
            name: json['name'] as String,
            type: json['type'] as String? ?? 'desktop',
            ip: dg.address.address,
            port: json['port'] as int? ?? 0,
            lastSeen: DateTime.now(),
          ));
        } catch (_) {}
      });

      // Broadcast presence every 2 seconds
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _broadcast();
      });
      _broadcast(); // immediate first broadcast

      ApexLogger.instance
          .log('UDP', '✅ Listening on port $_udpPort', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('UDP', '❌ Failed: $e', LogLevel.error);
    }
  }

  void _broadcast() {
    final d = _localDevice;
    if (d == null || _udpSocket == null) return;
    final msg = '$_magic${jsonEncode({
          'id': d.id,
          'name': d.name,
          'type': d.type,
          'port': d.port,
        })}';
    final data = utf8.encode(msg);
    // Send to both general broadcast and subnet broadcast
    for (final addr in _getBroadcastAddresses()) {
      try {
        _udpSocket!.send(data, InternetAddress(addr), _udpPort);
      } catch (_) {}
    }
  }

  List<String> _getBroadcastAddresses() {
    final addrs = <String>['255.255.255.255'];
    try {
      // Try to get subnet broadcast from local IP
      final ip = _localDevice?.ip;
      if (ip != null && ip != '127.0.0.1') {
        final parts = ip.split('.');
        if (parts.length == 4) {
          addrs.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
        }
      }
    } catch (_) {}
    return addrs;
  }

  // ─── Nearby Connections (Android phone ↔ phone) ───────────────────────────

  Future<void> _startNearby(Device localDevice) async {
    const serviceId = 'com.apexflow.tools.transfer';

    try {
      await Nearby().startAdvertising(
        localDevice.name,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (endpointId, info) async {
          ApexCore.instance.handleIncomingConnectionInitiated(endpointId);
        },
        onConnectionResult: (endpointId, status) {
          ApexLogger.instance
              .log('NEARBY', 'Connection result: $status', LogLevel.info);
        },
        onDisconnected: (endpointId) {
          _deviceLostController.add(endpointId);
        },
        serviceId: serviceId,
      );
      _nearbyAdvertising = true;
      ApexLogger.instance.log('NEARBY', '✅ Advertising', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('NEARBY', 'Advertise failed: $e', LogLevel.error);
    }

    try {
      await Nearby().startDiscovery(
        localDevice.name,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, name, sid) {
          _deviceFoundController.add(Device(
            id: endpointId,
            name: name,
            type: 'phone',
            endpointId: endpointId,
            lastSeen: DateTime.now(),
          ));
        },
        onEndpointLost: (endpointId) {
          if (endpointId != null) _deviceLostController.add(endpointId);
        },
        serviceId: serviceId,
      );
      _nearbyDiscovering = true;
      ApexLogger.instance.log('NEARBY', '✅ Discovering', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('NEARBY', 'Discovery failed: $e', LogLevel.error);
    }
  }

  // ─── Stop ─────────────────────────────────────────────────────────────────

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;

    if (_nearbyAdvertising) {
      await Nearby().stopAdvertising();
      _nearbyAdvertising = false;
    }
    if (_nearbyDiscovering) {
      await Nearby().stopDiscovery();
      _nearbyDiscovering = false;
    }
  }

  void dispose() {
    stop();
    _deviceFoundController.close();
    _deviceLostController.close();
  }
}
