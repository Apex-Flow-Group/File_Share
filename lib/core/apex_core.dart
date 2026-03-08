import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../managers/device_manager.dart';
import '../models/device.dart';
import '../models/transfer_progress.dart';
import '../services/network_discovery_service.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';

class ApexCore {
  static final ApexCore _instance = ApexCore._internal();
  static ApexCore get instance => _instance;
  ApexCore._internal();

  Device? _localDevice;
  final Map<String, Device> _discoveredDevices = {};
  final Map<String, Completer<bool>> _pendingRequests = {};
  HttpServer? _httpServer;
  NetworkDiscoveryService? _discoveryService;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  bool _isRunning = false;
  int _actualHttpPort = 0;

  static const int udpPort = 45679;
  static const String broadcastAddress = '255.255.255.255';
  static const Duration broadcastInterval = Duration(seconds: 3);
  static const Duration deviceTimeout = Duration(seconds: 10);

  final _devicesController = StreamController<List<Device>>.broadcast();
  final _fileReceivedController =
      StreamController<FileReceivedEvent>.broadcast();
  final _connectionRequestController =
      StreamController<ConnectionRequest>.broadcast();
  final _messageReceivedController =
      StreamController<ChatMessageEvent>.broadcast();

  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<FileReceivedEvent> get fileReceivedStream =>
      _fileReceivedController.stream;
  Stream<ConnectionRequest> get connectionRequestStream =>
      _connectionRequestController.stream;
  Stream<ChatMessageEvent> get messageReceivedStream =>
      _messageReceivedController.stream;
  Device? get localDevice => _localDevice;
  List<Device> get devices => _discoveredDevices.values.toList();
  bool get isRunning => _isRunning;

  Future<void> initialize() async {
    if (_isRunning) {
      return;
    }
    try {
      final deviceName = await DeviceManager.getDeviceName('Apex Device');
      final deviceType = DeviceManager.getDeviceType();
      final localIp = await _getLocalIp();
      _localDevice = Device(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        name: deviceName,
        ip: localIp,
        type: deviceType,
        port: 0,
      );
      ApexLogger.instance.log(
          'CORE',
          '✅ تم تهيئة الجهاز: ${_localDevice!.name} ($localIp)',
          LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('CORE', '❌ فشل التهيئة: $e', LogLevel.error);
      rethrow;
    }
  }

  Future<void> start() async {
    if (_isRunning) {
      return;
    }
    if (_localDevice == null) {
      await initialize();
    }
    try {
      await _startHttpServer();
      await _startUdpDiscovery();
      _startBroadcasting();
      _startCleanup();
      _isRunning = true;
      ApexLogger.instance.log('CORE', '🚀 النظام يعمل بنجاح', LogLevel.success);
    } catch (e) {
      ApexLogger.instance.log('CORE', '❌ فشل بدء النظام: $e', LogLevel.error);
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }
    _isRunning = false;
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    await _httpServer?.close();
    _discoveryService?.dispose();
    _discoveryService = null;
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  Future<void> _startHttpServer() async {
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _actualHttpPort = _httpServer!.port;
    _localDevice = _localDevice!.copyWith(port: _actualHttpPort);
    _httpServer!.listen(_handleHttpRequest);
    ApexLogger.instance.log(
        'HTTP', '✅ HTTP Server يعمل على المنفذ $_actualHttpPort', LogLevel.success);
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/ping') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('pong');
        await request.response.close();
      } else if (request.method == 'POST' &&
          request.uri.path == '/request-permission') {
        await _handlePermissionRequest(request);
      } else if (request.method == 'POST' && request.uri.path == '/upload') {
        await _handleFileUpload(request);
      } else if (request.method == 'POST' &&
          request.uri.path == '/send-message') {
        await _handleChatMessage(request);
      } else if (request.method == 'GET' &&
          request.uri.path == '/check-space') {
        await _handleCheckSpace(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _handlePermissionRequest(HttpRequest request) async {
    try {
      final fileName = request.uri.queryParameters['name'] ?? 'unknown';
      final fromDevice = request.uri.queryParameters['from'] ?? 'Unknown';
      final fromIp = request.uri.queryParameters['ip'] ?? 'Unknown';
      final requestType = request.uri.queryParameters['type'] ?? 'file';
      final fileSizeStr = request.uri.queryParameters['size'] ?? '0';
      final fileSize = int.tryParse(fileSizeStr) ?? 0;
      final requestId = '${fromIp}_${DateTime.now().millisecondsSinceEpoch}';

      final completer = Completer<bool>();
      _pendingRequests[requestId] = completer;

      _connectionRequestController.add(ConnectionRequest(
        device: Device(
            id: requestId,
            name: fromDevice,
            ip: fromIp,
            type: 'unknown',
            port: _actualHttpPort),
        fileName: fileName,
        fileSize: fileSize,
        requestType: requestType,
        onResponse: (accepted) {
          if (!completer.isCompleted) {
            completer.complete(accepted);
          }
        },
      ));

      final accepted = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );

      _pendingRequests.remove(requestId);

      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'accepted': accepted}));
      await request.response.close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(jsonEncode({'accepted': false}));
      await request.response.close();
    }
  }

  Future<void> _handleChatMessage(HttpRequest request) async {
    try {
      final message = request.uri.queryParameters['message'] ?? '';
      final fromDevice = request.uri.queryParameters['from'] ?? 'Unknown';
      final fromIp = request.uri.queryParameters['ip'] ?? 'Unknown';

      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true}));
      await request.response.close();

      _messageReceivedController.add(ChatMessageEvent(
        message: message,
        fromDevice: fromDevice,
        fromIp: fromIp,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(jsonEncode({'success': false}));
      await request.response.close();
    }
  }

  Future<void> _handleCheckSpace(HttpRequest request) async {
    try {
      final sizeStr = request.uri.queryParameters['size'] ?? '0';
      final requiredSize = int.tryParse(sizeStr) ?? 0;

      // تقدير تقريبي - افتراض وجود مساحة كافية
      final hasSpace = requiredSize < (100 * 1024 * 1024); // افتراضي 100MB

      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'hasSpace': hasSpace}));
      await request.response.close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'hasSpace': true}));
      await request.response.close();
    }
  }

  Future<void> _handleFileUpload(HttpRequest request) async {
    try {
      final rawFileName = request.uri.queryParameters['name'] ?? 'unknown';
      final fileName = _sanitizeFileName(rawFileName);
      final fromDevice = request.uri.queryParameters['from'] ?? 'Unknown';

      final dirPath = await PathUtils.getCategoryPath(fileName);
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$dirPath/$fileName';
      final file = File(filePath);
      final sink = file.openWrite();

      int totalBytes = 0;
      await for (final chunk in request) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }
      await sink.flush().timeout(const Duration(seconds: 10));
      await sink.close().timeout(const Duration(seconds: 10));

      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true, 'size': totalBytes}));
      await request.response.close();

      _fileReceivedController.add(FileReceivedEvent(
        fileName: fileName,
        fileSize: totalBytes,
        fromDevice: fromDevice,
        filePath: filePath,
      ));
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(jsonEncode({'success': false}));
      await request.response.close();
    }
  }

  Future<void> _startUdpDiscovery() async {
    _discoveryService = NetworkDiscoveryService();
    await _discoveryService!.startListening(_localDevice!);
    
    _discoveryService!.onDeviceFound.listen((device) {
      _discoveredDevices[device.id] = device;
      _devicesController.add(devices);
    });
    
    ApexLogger.instance.log('UDP', '✅ UDP Discovery يعمل على المنفذ $udpPort', LogLevel.success);
  }

  void _startBroadcasting() {
    _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _broadcastPresence());
    _broadcastPresence();
  }

  void _broadcastPresence() {
    if (_discoveryService == null) {
      return;
    }
    try {
      _discoveryService!.searchForDevices();
    } catch (e) {
      // Ignore broadcast errors
    }
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(deviceTimeout, (_) {
      final now = DateTime.now();
      _discoveredDevices.removeWhere((id, device) {
        return now.difference(device.lastSeen ?? now).inSeconds >
            deviceTimeout.inSeconds;
      });
      if (_discoveredDevices.isNotEmpty) {
        _devicesController.add(devices);
      }
    });
  }

  Future<bool> sendFile(String filePath, Device targetDevice) async {
    return sendFileWithName(filePath, filePath.split('/').last, targetDevice);
  }

  Future<bool> sendFileWithName(
      String filePath, String customFileName, Device targetDevice) async {
    final progressService = TransferProgressService();
    final startTime = DateTime.now();
    HttpClient? client;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      if (!await _checkConnection(targetDevice)) {
        return false;
      }

      final fileSize = await file.length();

      // فحص المساحة المتوفرة على الجهاز المستقبل
      final hasSpace = await _checkAvailableSpace(targetDevice, fileSize);
      if (!hasSpace) {
        ApexLogger.instance.log('TRANSFER',
            '❌ مساحة غير كافية على الجهاز المستقبل', LogLevel.error);
        return false;
      }

      if (!await _requestPermission(targetDevice, customFileName,
          fileSize: fileSize)) {
        return false;
      }

      progressService.updateProgress(TransferProgress(
        fileName: customFileName,
        totalBytes: fileSize,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: startTime,
      ));

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      final uri =
          Uri.http('${targetDevice.ip}:${targetDevice.port}', '/upload', {
        'name': customFileName,
        'from': _localDevice?.name ?? 'Unknown',
      });

      final request = await client.postUrl(uri);
      request.headers.set('Content-Length', fileSize.toString());

      int transferred = 0;
      const chunkSize = 65536;
      await for (final chunk in file.openRead(0, fileSize)) {
        if (progressService.isCancelled) {
          await request.close();
          return false;
        }

        request.add(chunk);
        transferred += chunk.length;

        if (transferred % (chunkSize * 8) == 0 || transferred == fileSize) {
          progressService.updateProgress(TransferProgress(
            fileName: customFileName,
            totalBytes: fileSize,
            transferredBytes: transferred,
            status: TransferStatus.transferring,
            startTime: startTime,
          ));
        }
      }

      final response = await request.close();
      final result = jsonDecode(await response.transform(utf8.decoder).join());
      return result['success'] == true;
    } catch (e) {
      return false;
    } finally {
      client?.close(force: true);
      await Future.delayed(const Duration(milliseconds: 500));
      progressService.clearProgress();
    }
  }

  Future<bool> sendMessage(String message, Device targetDevice) async {
    HttpClient? client;
    try {
      if (!await _checkConnection(targetDevice)) {
        ApexLogger.instance.log('CHAT', '❌ الجهاز غير متصل', LogLevel.error);
        return false;
      }

      // طلب إذن أولاً
      if (!await _requestPermission(targetDevice, message, type: 'chat')) {
        ApexLogger.instance.log('CHAT', '❌ تم رفض الرسالة', LogLevel.warning);
        return false;
      }

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final uri =
          Uri.http('${targetDevice.ip}:${targetDevice.port}', '/send-message', {
        'message': message,
        'from': _localDevice?.name ?? 'Unknown',
        'ip': _localDevice?.ip ?? 'Unknown',
      });

      final request = await client.postUrl(uri);
      final response = await request.close();
      final result = jsonDecode(await response.transform(utf8.decoder).join());
      
      if (result['success'] == true) {
        ApexLogger.instance.log('CHAT', '✅ تم إرسال الرسالة', LogLevel.success);
        return true;
      }
      return false;
    } catch (e) {
      ApexLogger.instance.log('CHAT', '❌ فشل إرسال الرسالة: $e', LogLevel.error);
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _requestPermission(Device targetDevice, String fileName,
      {String type = 'file', int fileSize = 0}) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.http(
          '${targetDevice.ip}:${targetDevice.port}', '/request-permission', {
        'name': fileName,
        'from': _localDevice?.name ?? 'Unknown',
        'ip': _localDevice?.ip ?? 'Unknown',
        'type': type,
        'size': fileSize.toString(),
      });

      final request = await client.postUrl(uri);
      final response = await request.close();
      final result = jsonDecode(await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 35)));
      return result['accepted'] == true;
    } catch (e) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _checkConnection(Device device) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.get(device.ip, device.port, '/ping');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<String> _getLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        if (interface.name.contains('wlan') ||
            interface.name.contains('WiFi')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Ignore network interface errors
    }
    return '192.168.1.100';
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/\x00]'), '_').replaceAll('..', '_');
  }

  Future<bool> _checkAvailableSpace(
      Device targetDevice, int requiredSize) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri =
          Uri.http('${targetDevice.ip}:${targetDevice.port}', '/check-space', {
        'size': requiredSize.toString(),
      });
      final request = await client.getUrl(uri);
      final response = await request.close();
      final result = jsonDecode(await response.transform(utf8.decoder).join());
      return result['hasSpace'] == true;
    } catch (e) {
      return true; // افتراض وجود مساحة في حالة الخطأ
    } finally {
      client?.close(force: true);
    }
  }

  void dispose() {
    stop();
    _devicesController.close();
    _fileReceivedController.close();
    _connectionRequestController.close();
    _messageReceivedController.close();
  }
}

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
  final String requestType;
  final Function(bool) onResponse;

  ConnectionRequest({
    required this.device,
    required this.fileName,
    required this.onResponse, this.fileSize = 0,
    this.requestType = 'file',
  });
}

class ChatMessageEvent {
  final String message;
  final String fromDevice;
  final String fromIp;
  final DateTime timestamp;

  ChatMessageEvent({
    required this.message,
    required this.fromDevice,
    required this.fromIp,
    required this.timestamp,
  });
}
