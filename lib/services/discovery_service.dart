import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../core/apex_core.dart';
import '../models/device.dart';
import '../utils/apex_logger.dart';

const _serviceType = '_apextransfer._tcp';

class DiscoveryService {
  final _deviceFoundController = StreamController<Device>.broadcast();
  final _deviceLostController = StreamController<String>.broadcast();

  Stream<Device> get onDeviceFound => _deviceFoundController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  BonsoirDiscovery? _discovery;
  BonsoirBroadcast? _broadcast;
  bool _nearbyAdvertising = false;
  bool _nearbyDiscovering = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Android: runs BOTH Nearby (phone↔phone) AND mDNS (phone↔PC)
  /// Desktop: runs mDNS only
  Future<void> start(Device localDevice) async {
    if (_isAndroid) {
      // Run both in parallel - errors in one don't stop the other
      await Future.wait([
        _startNearby(localDevice),
        _startMdns(localDevice),
      ]);
    } else {
      await _startMdns(localDevice);
    }
  }

  // ─── Nearby Connections (phone ↔ phone) ───────────────────────────────────

  Future<void> _startNearby(Device localDevice) async {
    const serviceId = 'com.apexflow.tools.transfer';

    try {
      await Nearby().startAdvertising(
        localDevice.name,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (endpointId, info) async {
          // Delegate to ApexCore so it registers the correct payload callbacks
          ApexCore.instance.handleIncomingConnectionInitiated(endpointId);
        },
        onConnectionResult: (endpointId, status) {
          ApexLogger.instance
              .log('NEARBY', 'Connection: $status', LogLevel.info);
        },
        onDisconnected: (endpointId) {
          _deviceLostController.add(endpointId);
        },
        serviceId: serviceId,
      );
      _nearbyAdvertising = true;
      ApexLogger.instance.log('NEARBY', '✅ Advertising started', LogLevel.success);
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
          if (endpointId != null) {
            _deviceLostController.add(endpointId);
          }
        },
        serviceId: serviceId,
      );
      _nearbyDiscovering = true;
      ApexLogger.instance.log('NEARBY', '✅ Discovery started', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('NEARBY', 'Discovery failed: $e', LogLevel.error);
    }
  }

  // ─── mDNS / Bonsoir (phone ↔ PC and PC ↔ PC) ─────────────────────────────

  Future<void> _startMdns(Device localDevice) async {
    final servicePort = localDevice.port > 0 ? localDevice.port : 45680;

    try {
      _broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: localDevice.name,
          type: _serviceType,
          port: servicePort,
          attributes: {
            'id': localDevice.id,
            'type': localDevice.type,
            'port': '$servicePort',
          },
        ),
      );
      await _broadcast!.start();
      ApexLogger.instance.log('MDNS', '✅ Broadcasting on port $servicePort', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('MDNS', 'Broadcast failed: $e', LogLevel.error);
    }

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);

      _discovery!.eventStream?.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          _discovery!.serviceResolver.resolveService(event.service);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final svc = event.service;
          final attrs = svc.attributes;
          final id = attrs['id'] ?? svc.name;
          final port = int.tryParse(attrs['port'] ?? '') ?? svc.port;
          final host = svc.host ?? '';

          // Skip if no IP (can't transfer files)
          if (host.isEmpty) {
            return;
          }

          _deviceFoundController.add(Device(
            id: id,
            name: svc.name,
            type: attrs['type'] ?? 'desktop',
            ip: host,
            port: port,
            lastSeen: DateTime.now(),
          ));
          ApexLogger.instance.log('MDNS', '✅ Found: ${svc.name} @ $host:$port', LogLevel.success);
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          final id = event.service.attributes['id'] ?? event.service.name;
          _deviceLostController.add(id);
        }
      });

      await _discovery!.start();
      ApexLogger.instance.log('MDNS', '✅ Discovery started', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('MDNS', 'Discovery failed: $e', LogLevel.error);
    }
  }

  // ─── Stop ─────────────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (_nearbyAdvertising) {
      await Nearby().stopAdvertising();
      _nearbyAdvertising = false;
    }
    if (_nearbyDiscovering) {
      await Nearby().stopDiscovery();
      _nearbyDiscovering = false;
    }
    await _broadcast?.stop();
    await _discovery?.stop();
    _broadcast = null;
    _discovery = null;
  }

  void dispose() {
    stop();
    _deviceFoundController.close();
    _deviceLostController.close();
  }
}
