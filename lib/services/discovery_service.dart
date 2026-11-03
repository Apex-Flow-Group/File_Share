// ignore_for_file: always_put_control_body_on_new_line

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../core/apex_core.dart';
import '../core/protocol/discovery_packet.dart';
import '../core/text/clean_label.dart';
import '../models/device.dart';
import '../utils/apex_logger.dart';

class DiscoveryService {
  final _deviceFoundController = StreamController<Device>.broadcast();
  final _deviceLostController = StreamController<String>.broadcast();

  Stream<Device> get onDeviceFound => _deviceFoundController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  /// callback يُسأل عنه عند كل بث — هل Share مُفعَّل؟ (desktop فقط)
  bool Function() isShareEnabled;

  DiscoveryService({this.isShareEnabled = _defaultFalse});
  static bool _defaultFalse() => false;

  // Nearby (Android phone ↔ phone)
  bool _nearbyAdvertising = false;
  bool _nearbyDiscovering = false;

  // UDP broadcast (Desktop ↔ Desktop and Desktop ↔ Android)
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;
  Device? _localDevice;
  static const int _udpPort = 45679;

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
    final data = utf8.encode(DiscoveryPacket.encode(d, shareEnabled: isShareEnabled()));
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
        if (dg.address.address == localDevice.ip) return; // ignore self by IP
        try {
          final device = DiscoveryPacket.decode(utf8.decode(dg.data),
              from: dg.address.address, selfId: localDevice.id);
          if (device != null) _deviceFoundController.add(device);
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
    final data = utf8.encode(DiscoveryPacket.encode(d, shareEnabled: isShareEnabled()));
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
    const serviceId = DiscoveryPacket.nearbyServiceId;

    try {
      await Nearby().startAdvertising(
        localDevice.name,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (endpointId, info) async {
          ApexCore.instance
              .handleIncomingConnectionInitiated(endpointId, info.endpointName);
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
          final shown = cleanLabel(name);
          _deviceFoundController.add(Device(
            id: endpointId,
            name: shown.isEmpty ? endpointId : shown,
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
