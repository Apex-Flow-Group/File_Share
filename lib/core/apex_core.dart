import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../managers/device_manager.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../services/settings_service.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import 'core_models.dart';
import 'http_transfer.dart';
import 'nearby_transfer.dart';

export 'core_models.dart';

class ApexCore {
  static final ApexCore _instance = ApexCore._internal();
  static ApexCore get instance => _instance;
  ApexCore._internal();

  Device? _localDevice;
  final Map<String, Device> _discoveredDevices = {};

  HttpServer? _httpServer;
  DiscoveryService? _discoveryService;
  Timer? _cleanupTimer;
  bool _isRunning = false;
  int _httpPort = 0;
  NetworkMode _networkMode = NetworkMode.wifi;

  static const Duration _deviceTimeout = Duration(seconds: 60);

  final _devicesController = StreamController<List<Device>>.broadcast();
  final _fileReceivedController =
      StreamController<FileReceivedEvent>.broadcast();
  final _connectionRequestController =
      StreamController<ConnectionRequest>.broadcast();

  late final HttpTransfer _http = HttpTransfer(
    getLocalName: () => _localDevice?.name,
    getLocalIp: () => _localDevice?.ip,
    onFileReceived: _fileReceivedController.add,
    onConnectionRequest: _connectionRequestController.add,
  );

  late final NearbyTransfer _nearby = NearbyTransfer(
    getLocalName: () => _localDevice?.name,
    onFileReceived: _fileReceivedController.add,
    onConnectionRequest: _connectionRequestController.add,
    discoveredDevices: _discoveredDevices,
  );

  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<FileReceivedEvent> get fileReceivedStream =>
      _fileReceivedController.stream;
  Stream<ConnectionRequest> get connectionRequestStream =>
      _connectionRequestController.stream;
  Device? get localDevice => _localDevice;
  List<Device> get devices => _discoveredDevices.values.toList();
  bool get isRunning => _isRunning;

  void setNetworkMode(NetworkMode mode) => _networkMode = mode;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isRunning) {
      return;
    }
    final name = await DeviceManager.getDeviceName('Apex Device');
    final type = DeviceManager.getDeviceType();
    final ip = await _getLocalIp();
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = 'local-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
    }
    _localDevice = Device(
      id: deviceId,
      name: name,
      type: type,
      ip: ip,
    );
  }

  Future<void> start() async {
    if (_isRunning) {
      return;
    }
    if (_localDevice == null) {
      await initialize();
    }
    await _startHttpServer();

    _discoveryService = DiscoveryService();
    _discoveryService!.onDeviceFound.listen((device) {
      if (TransferProgressService().isTransferring) {
        return;
      }
      // deduplication بالاسم — ادمج Nearby + WiFi في سجل واحد
      final existingEntry = _discoveredDevices.entries
          .where((e) => e.value.name.toLowerCase() == device.name.toLowerCase())
          .firstOrNull;

      if (existingEntry != null) {
        final existing = existingEntry.value;
        if (device.isNearby && !existing.isNearby) {
          // جاء Nearby لجهاز WiFi موجود → ادمج: احتفظ بـ id الحالي وأضف endpointId
          _discoveredDevices[existingEntry.key] = existing.copyWith(
            endpointId: device.endpointId,
            lastSeen: DateTime.now(),
          );
        } else if (!device.isNearby && existing.isNearby) {
          // جاء WiFi لجهاز Nearby موجود → أضف IP/port للموجود
          _discoveredDevices[existingEntry.key] = existing.copyWith(
            ip: device.ip,
            port: device.port,
            lastSeen: DateTime.now(),
          );
        } else {
          // نفس النوع → حدّث lastSeen فقط
          _discoveredDevices[existingEntry.key] =
              existing.copyWith(lastSeen: DateTime.now());
        }
      } else {
        _discoveredDevices[device.id] = device;
      }
      _devicesController.add(devices);
    });
    _discoveryService!.onDeviceLost.listen((id) {
      if (TransferProgressService().isTransferring) {
        return;
      }
      _discoveredDevices.remove(id);
      _nearby.connectedEndpoints.remove(id);
      _devicesController.add(devices);
    });

    await _discoveryService!.start(_localDevice!.copyWith(port: _httpPort));
    _startCleanup();
    _isRunning = true;
    ApexLogger.instance.log('CORE', '🚀 النظام يعمل', LogLevel.success);
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }
    _isRunning = false;
    // إلغاء أي عملية نقل جارية قبل الإيقاف
    final progress = TransferProgressService();
    if (progress.isTransferring) {
      progress.cancelTransfer();
      progress.cancelReceive();
      // انتظار قصير ليتمكن الإرسال الحالي من التوقف بأمان
      await Future.delayed(const Duration(milliseconds: 300));
      progress.clearProgress();
    }
    _cleanupTimer?.cancel();
    await _httpServer?.close();
    if (_isAndroid) {
      await _nearby.stopAll();
    }
    await _discoveryService?.stop();
    _discoveryService = null;
    _discoveredDevices.clear();
    _nearby.connectedEndpoints.clear();
    _devicesController.add([]);
  }

  // ─── HTTP Server ───────────────────────────────────────────────────────────

  Future<void> _startHttpServer() async {
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _httpPort = _httpServer!.port;
    _localDevice = _localDevice!.copyWith(port: _httpPort);
    _httpServer!.listen(_handleRequest);
    ApexLogger.instance.log('HTTP', '✅ Port: $_httpPort', LogLevel.success);
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/ping') {
        req.response
          ..statusCode = HttpStatus.ok
          ..write('pong');
        await req.response.close();
      } else if (req.method == 'POST' && path == '/request') {
        await _http.handlePermissionRequest(req);
      } else if (req.method == 'POST' && path == '/upload') {
        await _http.handleUpload(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  // ─── Send ──────────────────────────────────────────────────────────────────

  Future<bool> sendFile(String filePath, Device target) =>
      sendFileWithName(filePath, filePath.split('/').last, target);

  Future<bool> sendFileWithName(
      String filePath, String fileName, Device target) async {
    if (_isAndroid && target.isNearby) {
      return _nearby.sendFile(filePath, fileName, target);
    }
    final f = File(filePath);
    if (!await f.exists()) {
      return false;
    }
    final size = await f.length();
    return _http
        .sendFiles([(path: filePath, name: fileName, size: size)], target);
  }

  Future<bool> sendFiles(List<String> filePaths, Device target) async {
    if (filePaths.isEmpty) {
      return false;
    }

    final files = <({String path, String name, int size})>[];
    for (final path in filePaths) {
      final f = File(path);
      if (!await f.exists()) {
        continue;
      }
      files.add(
          (path: path, name: path.split('/').last, size: await f.length()));
    }
    if (files.isEmpty) {
      return false;
    }

    if (_isAndroid && target.isNearby) {
      return _nearby.sendBatchFiles(files, target);
    }

    return _http.sendFiles(files, target);
  }

  // ─── Nearby incoming connection ────────────────────────────────────────────

  void handleIncomingConnectionInitiated(String endpointId) async {
    await _nearby.acceptConnection(endpointId);
    ApexLogger.instance
        .log('NEARBY', '✅ Accepted: $endpointId', LogLevel.success);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(_deviceTimeout, (_) {
      if (TransferProgressService().isTransferring) {
        return;
      }
      final now = DateTime.now();
      _discoveredDevices.removeWhere((_, d) =>
          d.lastSeen != null &&
          now.difference(d.lastSeen!).inSeconds > _deviceTimeout.inSeconds);
      _devicesController.add(devices);
    });
  }

  Future<String> _getLocalIp() async {
    try {
      // Android و iOS — استخدم NetworkInterface مباشرة
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );
        // أولوية لـ wlan/wifi
        for (final iface in interfaces) {
          final name = iface.name.toLowerCase();
          if (name.contains('wlan') || name.contains('wifi') || name.contains('wl')) {
            for (final addr in iface.addresses) {
              if (!addr.isLoopback) {
                return addr.address;
              }
            }
          }
        }
        // fallback لأي interface آخر
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
        return '127.0.0.1';
      }

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );
        final isWifi = _networkMode == NetworkMode.wifi;
        final wifiKeywords = ['wi-fi', 'wifi', 'wlan', 'wireless', 'wlp'];
        final lanKeywords = ['ethernet', 'eth', 'local area', 'enp', 'eno'];
        final keywords = isWifi ? wifiKeywords : lanKeywords;

        for (final iface in interfaces) {
          final name = iface.name.toLowerCase();
          if (keywords.any((k) => name.contains(k))) {
            for (final addr in iface.addresses) {
              if (!addr.isLoopback) {
                ApexLogger.instance.log(
                    'NET',
                    '${isWifi ? 'WiFi' : 'LAN'} iface: ${iface.name} -> ${addr.address}',
                    LogLevel.info);
                return addr.address;
              }
            }
          }
        }
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void dispose() {
    stop();
    _devicesController.close();
    _fileReceivedController.close();
    _connectionRequestController.close();
  }
}
