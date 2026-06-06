import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../managers/device_manager.dart';
import '../models/device.dart';
import '../models/transfer_progress.dart';
import '../services/discovery_service.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';

class ApexCore {
  static final ApexCore _instance = ApexCore._internal();
  static ApexCore get instance => _instance;
  ApexCore._internal();

  Device? _localDevice;
  final Map<String, Device> _discoveredDevices = {};

  // Nearby: track connected endpoints
  final Map<String, Completer<bool>> _nearbyConnectCompleters = {};
  final Set<String> _connectedEndpoints = {};

  // HTTP: track pending accept/reject dialogs
  final Map<String, Completer<bool>> _pendingRequests = {};

  HttpServer? _httpServer;
  DiscoveryService? _discoveryService;
  Timer? _cleanupTimer;
  bool _isRunning = false;
  int _httpPort = 0;

  static const Duration _deviceTimeout = Duration(seconds: 60);

  final _devicesController = StreamController<List<Device>>.broadcast();
  final _fileReceivedController =
      StreamController<FileReceivedEvent>.broadcast();
  final _connectionRequestController =
      StreamController<ConnectionRequest>.broadcast();

  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<FileReceivedEvent> get fileReceivedStream =>
      _fileReceivedController.stream;
  Stream<ConnectionRequest> get connectionRequestStream =>
      _connectionRequestController.stream;
  Device? get localDevice => _localDevice;
  List<Device> get devices => _discoveredDevices.values.toList();
  bool get isRunning => _isRunning;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isRunning) {
      return;
    }
    final name = await DeviceManager.getDeviceName('Apex Device');
    final type = DeviceManager.getDeviceType();
    final ip = await _getLocalIp();
    _localDevice = Device(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
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
      _discoveredDevices[device.id] = device;
      _devicesController.add(devices);
    });
    _discoveryService!.onDeviceLost.listen((id) {
      _discoveredDevices.remove(id);
      _connectedEndpoints.remove(id);
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
    _cleanupTimer?.cancel();
    await _httpServer?.close();
    if (_isAndroid) {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    }
    await _discoveryService?.stop();
    _discoveryService = null;
    _discoveredDevices.clear();
    _connectedEndpoints.clear();
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
        req.response..statusCode = HttpStatus.ok..write('pong');
        await req.response.close();
      } else if (req.method == 'POST' && path == '/request') {
        await _handlePermissionRequest(req);
      } else if (req.method == 'POST' && path == '/upload') {
        await _handleUpload(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (_) {
      req.response.statusCode = HttpStatus.internalServerError;
      await req.response.close();
    }
  }

  Future<void> _handlePermissionRequest(HttpRequest req) async {
    final fileName = req.uri.queryParameters['name'] ?? 'unknown';
    final fromDevice = req.uri.queryParameters['from'] ?? 'Unknown';
    final fromIp = req.uri.queryParameters['ip'] ?? '';
    final fileSize =
        int.tryParse(req.uri.queryParameters['size'] ?? '') ?? 0;
    final requestId = '${fromIp}_${DateTime.now().millisecondsSinceEpoch}';

    final completer = Completer<bool>();
    _pendingRequests[requestId] = completer;

    _connectionRequestController.add(ConnectionRequest(
      device: Device(
          id: requestId, name: fromDevice, type: 'unknown', ip: fromIp),
      fileName: fileName,
      fileSize: fileSize,
      onResponse: (v) {
        if (!completer.isCompleted) {
          completer.complete(v);
        }
      },
    ));

    final accepted = await completer.future
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
    _pendingRequests.remove(requestId);

    req.response
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'accepted': accepted}));
    await req.response.close();
  }

  Future<void> _handleUpload(HttpRequest req) async {
    final fileName = _sanitize(req.uri.queryParameters['name'] ?? 'unknown');
    final fromDevice = req.uri.queryParameters['from'] ?? 'Unknown';

    final dirPath = await PathUtils.getCategoryPath(fileName);
    await Directory(dirPath).create(recursive: true);
    final filePath = '$dirPath/$fileName';
    final sink = File(filePath).openWrite();

    int total = 0;
    await for (final chunk in req) {
      sink.add(chunk);
      total += chunk.length;
    }
    await sink.flush();
    await sink.close();

    req.response
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'success': true}));
    await req.response.close();

    _fileReceivedController.add(FileReceivedEvent(
      fileName: fileName,
      fileSize: total,
      fromDevice: fromDevice,
      filePath: filePath,
    ));
  }

  // ─── Send File (public API) ────────────────────────────────────────────────

  Future<bool> sendFile(String filePath, Device target) =>
      sendFileWithName(filePath, filePath.split('/').last, target);

  Future<bool> sendFileWithName(
      String filePath, String fileName, Device target) async {
    if (_isAndroid && target.isNearby) {
      return _sendViaNearby(filePath, fileName, target);
    }
    return _sendViaHttp(filePath, fileName, target);
  }

  // ─── Nearby Send ───────────────────────────────────────────────────────────
  //
  // Official Nearby Connections flow:
  //   1. Discoverer calls requestConnection()
  //   2. Both sides receive onConnectionInitiated → call acceptConnection()
  //   3. onConnectionResult fires with Status.CONNECTED
  //   4. Now sendFilePayload() can be called
  //   5. Receiver gets onPayLoadReceived with the file

  Future<bool> _sendViaNearby(
      String filePath, String fileName, Device target) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }
    final fileSize = await file.length();
    final endpointId = target.endpointId!;

    final progress = TransferProgressService();

    // ── Step 1: connect if not already connected ──────────────────────────
    if (!_connectedEndpoints.contains(endpointId)) {
      final connected = await _connectNearby(endpointId, target.name);
      if (!connected) {
        ApexLogger.instance
            .log('NEARBY', '❌ Connection failed to $endpointId', LogLevel.error);
        return false;
      }
    }

    // ── Step 2: show accept dialog on receiver side via Nearby bytes payload
    //    We send a small JSON "request" first, wait for acceptance
    final accepted = await _requestViaNearbyBytes(
        endpointId, fileName, fileSize, target.name);
    if (!accepted) {
      ApexLogger.instance.log('NEARBY', '❌ Transfer rejected', LogLevel.warning);
      return false;
    }

    // ── Step 3: send the file ──────────────────────────────────────────────
    try {
      progress.updateProgress(TransferProgress(
        fileName: fileName,
        totalBytes: fileSize,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      ));

      final payloadId =
          await Nearby().sendFilePayload(endpointId, filePath);
      ApexLogger.instance
          .log('NEARBY', '✅ File payload sent: $payloadId', LogLevel.success);
      return true;
    } catch (e) {
      ApexLogger.instance
          .log('NEARBY', '❌ sendFilePayload failed: $e', LogLevel.error);
      return false;
    } finally {
      await Future.delayed(const Duration(seconds: 1));
      progress.clearProgress();
    }
  }

  /// Initiates a Nearby connection from the discoverer side.
  Future<bool> _connectNearby(String endpointId, String remoteName) async {
    final completer = Completer<bool>();
    _nearbyConnectCompleters[endpointId] = completer;

    try {
      await Nearby().requestConnection(
        _localDevice?.name ?? 'Apex',
        endpointId,
        onConnectionInitiated: (eid, info) async {
          ApexLogger.instance
              .log('NEARBY', 'Connection initiated with $eid', LogLevel.info);
          // Accept on our (sender) side
          await Nearby().acceptConnection(
            eid,
            onPayLoadRecieved: _onPayloadReceived,
            onPayloadTransferUpdate: _onPayloadTransferUpdate,
          );
        },
        onConnectionResult: (eid, status) {
          ApexLogger.instance
              .log('NEARBY', 'Connection result: $status', LogLevel.info);
          final c = _nearbyConnectCompleters.remove(eid);
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(eid);
            c?.complete(true);
          } else {
            c?.complete(false);
          }
        },
        onDisconnected: (eid) {
          _connectedEndpoints.remove(eid);
          _deviceLostFromEndpoint(eid);
          ApexLogger.instance
              .log('NEARBY', 'Disconnected: $eid', LogLevel.warning);
        },
      );
    } catch (e) {
      _nearbyConnectCompleters.remove(endpointId)?.complete(false);
      ApexLogger.instance
          .log('NEARBY', '❌ requestConnection failed: $e', LogLevel.error);
      return false;
    }

    return completer.future
        .timeout(const Duration(seconds: 15), onTimeout: () {
      _nearbyConnectCompleters.remove(endpointId);
      return false;
    });
  }

  /// Send a small JSON bytes payload asking receiver to accept the file.
  /// We reuse the _pendingRequests map with endpointId as key.
  Future<bool> _requestViaNearbyBytes(
      String endpointId, String fileName, int fileSize, String senderName) async {
    final completer = Completer<bool>();
    _pendingRequests[endpointId] = completer;

    final msg = jsonEncode({
      'type': 'request',
      'name': fileName,
      'size': fileSize,
      'from': senderName,
    });

    try {
      await Nearby()
          .sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(msg)));
    } catch (e) {
      _pendingRequests.remove(endpointId);
      return false;
    }

    return completer.future
        .timeout(const Duration(seconds: 30), onTimeout: () {
      _pendingRequests.remove(endpointId);
      return false;
    });
  }

  // ─── Nearby Payload Callbacks ──────────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) async {
    // Refresh lastSeen so device doesn't get cleaned up during transfer
    if (_discoveredDevices.containsKey(endpointId)) {
      _discoveredDevices[endpointId] =
          _discoveredDevices[endpointId]!.copyWith(lastSeen: DateTime.now());
    }

    if (payload.type == PayloadType.BYTES) {
      _handleNearbyBytes(endpointId, payload.bytes!);
    } else if (payload.type == PayloadType.FILE) {
      await _handleNearbyFile(endpointId, payload);
    }
  }

  void _onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) {
    final progress = TransferProgressService();
    if (update.status == PayloadStatus.IN_PROGRESS) {
      progress.updateProgress(TransferProgress(
        fileName: 'receiving...',
        totalBytes: update.totalBytes,
        transferredBytes: update.bytesTransferred,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      ));
    } else if (update.status == PayloadStatus.SUCCESS) {
      progress.clearProgress();
    } else if (update.status == PayloadStatus.FAILURE) {
      progress.clearProgress();
    }
  }

  void _handleNearbyBytes(String endpointId, Uint8List bytes) {
    try {
      final msg = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      if (msg['type'] == 'request') {
        // Receiver side: show accept dialog
        final fileName = msg['name'] as String? ?? 'unknown';
        final fileSize = (msg['size'] as num?)?.toInt() ?? 0;
        final fromName = msg['from'] as String? ?? 'Unknown';
        final requestId = endpointId;

        final completer = Completer<bool>();
        _pendingRequests[requestId] = completer;

        _connectionRequestController.add(ConnectionRequest(
          device: _discoveredDevices[endpointId] ??
              Device(
                  id: endpointId,
                  name: fromName,
                  type: 'phone',
                  endpointId: endpointId),
          fileName: fileName,
          fileSize: fileSize,
          onResponse: (v) async {
            if (!completer.isCompleted) {
              completer.complete(v);
            }
            // Send response back
            final resp = jsonEncode({'type': 'response', 'accepted': v});
            await Nearby().sendBytesPayload(
                endpointId, Uint8List.fromList(utf8.encode(resp)));
          },
        ));
      } else if (msg['type'] == 'response') {
        // Sender side: receive accept/reject
        final accepted = msg['accepted'] as bool? ?? false;
        _pendingRequests.remove(endpointId)?.complete(accepted);
      }
    } catch (e) {
      ApexLogger.instance
          .log('NEARBY', 'Bytes parse error: $e', LogLevel.error);
    }
  }

  Future<void> _handleNearbyFile(String endpointId, Payload payload) async {
    try {
      // The file lands in the app cache - move it to downloads
      final cachedUri = payload.filePath;
      if (cachedUri == null) {
        return;
      }

      final cachedFile = File(cachedUri);
      final fileName = cachedFile.path.split('/').last;
      final dirPath = await PathUtils.getCategoryPath(fileName);
      await Directory(dirPath).create(recursive: true);
      final destPath = '$dirPath/$fileName';
      await cachedFile.copy(destPath);
      await cachedFile.delete();

      final device = _discoveredDevices[endpointId];
      _fileReceivedController.add(FileReceivedEvent(
        fileName: fileName,
        fileSize: await File(destPath).length(),
        fromDevice: device?.name ?? endpointId,
        filePath: destPath,
      ));
      ApexLogger.instance
          .log('NEARBY', '✅ File saved: $destPath', LogLevel.success);
    } catch (e) {
      ApexLogger.instance
          .log('NEARBY', '❌ File handle error: $e', LogLevel.error);
    }
  }

  void _deviceLostFromEndpoint(String endpointId) {
    _discoveredDevices.remove(endpointId);
    _devicesController.add(devices);
  }

  // ─── HTTP Send (mDNS / Desktop) ────────────────────────────────────────────

  Future<bool> _sendViaHttp(
      String filePath, String fileName, Device target) async {
    final progress = TransferProgressService();
    final startTime = DateTime.now();
    HttpClient? client;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      if (!await _ping(target)) {
        return false;
      }

      final fileSize = await file.length();
      if (!await _requestViaHttp(target, fileName, fileSize)) {
        return false;
      }

      progress.updateProgress(TransferProgress(
        fileName: fileName,
        totalBytes: fileSize,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: startTime,
      ));

      client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
      final uri = Uri.http('${target.ip}:${target.port}', '/upload', {
        'name': fileName,
        'from': _localDevice?.name ?? 'Unknown',
      });
      final req = await client.postUrl(uri);
      req.headers.set('Content-Length', fileSize.toString());

      int transferred = 0;
      await for (final chunk in file.openRead()) {
        if (progress.isCancelled) {
          await req.close();
          return false;
        }
        req.add(chunk);
        transferred += chunk.length;
        if (transferred % (65536 * 8) == 0 || transferred == fileSize) {
          progress.updateProgress(TransferProgress(
            fileName: fileName,
            totalBytes: fileSize,
            transferredBytes: transferred,
            status: TransferStatus.transferring,
            startTime: startTime,
          ));
        }
      }
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join());
      return body['success'] == true;
    } catch (e) {
      ApexLogger.instance.log('HTTP', '❌ Send failed: $e', LogLevel.error);
      return false;
    } finally {
      client?.close(force: true);
      await Future.delayed(const Duration(milliseconds: 300));
      progress.clearProgress();
    }
  }

  Future<bool> _requestViaHttp(
      Device target, String fileName, int fileSize) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.http('${target.ip}:${target.port}', '/request', {
        'name': fileName,
        'from': _localDevice?.name ?? 'Unknown',
        'ip': _localDevice?.ip ?? '',
        'size': fileSize.toString(),
      });
      final req = await client.postUrl(uri);
      final res = await req.close();
      final body = jsonDecode(await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 35)));
      return body['accepted'] == true;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _ping(Device device) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.get(device.ip, device.port, '/ping');
      final res = await req.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  // ─── Nearby Advertiser Accept (incoming connections) ──────────────────────
  //
  // When another device requests connection TO us (we are advertising),
  // the DiscoveryService.onConnectionInitiated fires → we accept there.
  // But we need to register proper payload callbacks.
  // We expose this so DiscoveryService can call it.

  void handleIncomingConnectionInitiated(String endpointId) async {
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
    _connectedEndpoints.add(endpointId);
    ApexLogger.instance
        .log('NEARBY', '✅ Accepted incoming from $endpointId', LogLevel.success);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(_deviceTimeout, (_) {
      final now = DateTime.now();
      _discoveredDevices.removeWhere((_, d) =>
          d.lastSeen != null &&
          now.difference(d.lastSeen!).inSeconds > _deviceTimeout.inSeconds);
      _devicesController.add(devices);
    });
  }

  Future<String> _getLocalIp() async {
    try {
      for (final iface in await NetworkInterface.list()) {
        if (iface.name.toLowerCase().contains('wlan') ||
            iface.name.toLowerCase().contains('wifi') ||
            iface.name.toLowerCase().contains('eth')) {
          for (final addr in iface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/\x00]'), '_').replaceAll('..', '_');

  void dispose() {
    stop();
    _devicesController.close();
    _fileReceivedController.close();
    _connectionRequestController.close();
  }
}

// ─── Events ───────────────────────────────────────────────────────────────────

class FileReceivedEvent {
  final String fileName;
  final int fileSize;
  final String fromDevice;
  final String filePath;
  FileReceivedEvent({
    required this.fileName,
    required this.fileSize,
    required this.fromDevice,
    required this.filePath,
  });
}

class ConnectionRequest {
  final Device device;
  final String fileName;
  final int fileSize;
  final Function(bool) onResponse;
  ConnectionRequest({
    required this.device,
    required this.fileName,
    required this.onResponse,
    this.fileSize = 0,
  });
}
