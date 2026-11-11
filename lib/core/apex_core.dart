import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/chat/data/chat_http.dart';
import '../features/chat/logic/chat_key.dart';
import '../features/chat/logic/chat_store.dart';
import '../features/identity/device_identity.dart';
import '../features/identity/peer_trust.dart';
import '../features/identity/pin_store.dart';
import '../features/receive/data/receive_http.dart';
import '../features/receive/data/receive_store.dart';
import '../features/receive/logic/receive_gate.dart';
import '../features/send/data/send_http.dart';
import '../managers/device_manager.dart';
import '../models/device.dart';
import '../platform/free_space.dart';
import '../platform/owner_only.dart';
import '../services/discovery_service.dart';
import '../services/settings_service.dart';
import '../services/transfer_progress_service.dart';
import '../utils/apex_logger.dart';
import '../utils/path_utils.dart';
import 'core_models.dart';
import 'discovery_merge.dart';
import 'files/move_into_folder.dart';
import 'nearby_transfer.dart';
import 'one_question.dart';
import 'share_folder_http.dart';

export 'core_models.dart';

class ApexCore {
  static final ApexCore _instance = ApexCore._internal();
  static ApexCore get instance => _instance;
  ApexCore._internal();

  Device? _localDevice;
  final Map<String, Device> _discoveredDevices = {};

  HttpServer? _httpServer;

  /// This install's certificate, read in [initialize].
  DeviceIdentity? _identity;
  SecurityContext? _clientContext;
  SecurityContext? _serverContext;
  PeerTrust? _peerTrust;

  /// Whom the user accepted, by id and fingerprint; on disk once [initialize] ran.
  final _pins = PinStore.memory();
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

  /// Files, chat and the shared folder never ask the user at the same time.
  final _question = OneQuestion();

  late final ReceiveHttp _receive = ReceiveHttp(
    gate: ReceiveGate(),
    store: ReceiveStore(
      tempFolder: () async => Directory(
          _isAndroid ? await PathUtils.getTempCachePath() : await PathUtils.getReceivingPath()),
      place: _placeReceived,
    ),
    onConnectionRequest: _connectionRequestController.add,
    onFileReceived: (e) {
      _fileReceivedController.add(e);
      chat.receivedFile(e);
    },
    freeBytes: () async => freeBytesAt(await PathUtils.getDownloadPath()),
    expectedFingerprint: _expectedFingerprint,
    pins: _pins,
    question: _question,
  );

  late final SendHttp _send = SendHttp(
      getLocalName: () => _localDevice?.name,
      getLocalId: () => _localDevice?.id,
      getContext: () => _clientContext);

  late final ShareFolderHttp _share = ShareFolderHttp(
    isEnabled: () => _settings?.sharedFolderEnabled ?? false,
    allowUploads: () => _settings?.allowShareUploads ?? false,
    getLocalName: () => _localDevice?.name,
    onAccessRequest: _connectionRequestController.add,
    expectedFingerprint: _expectedFingerprint,
    pins: _pins,
    question: _question,
  );

  late final ChatHttp _chat = ChatHttp(
    onRequest: _connectionRequestController.add,
    onMessage: (m) => chat.receive(chatKey(m.id, m.address), m.name, m.text),
    onBlocked: (key) => chat.blocked(key),
    expectedFingerprint: _expectedFingerprint,
    pins: _pins,
    question: _question,
  );

  /// The chats of this run, in memory only.
  late final ChatStore chat = ChatStore(
    send: _sendChat,
    // Sizes are read now: a file that changed since its line was made would
    // otherwise go cut to its old size and be taken as complete.
    sendFilesNow: (files, target, onDelivered) async => _send.sendFiles(
        [for (final f in files) (path: f.path, name: f.name, size: await File(f.path).length())], target,
        onDelivered: onDelivered),
    onBlock: _chat.block,
    onUnblock: _chat.unblock,
  );
  SettingsService? _settings;

  late final NearbyTransfer _nearby = NearbyTransfer(
    getLocalName: () => _localDevice?.name,
    onFileReceived: _fileReceivedController.add,
    onConnectionRequest: _connectionRequestController.add,
    place: _placeReceived,
    discoveredDevices: _discoveredDevices,
    question: _question,
  );

  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<FileReceivedEvent> get fileReceivedStream =>
      _fileReceivedController.stream;
  Stream<ConnectionRequest> get connectionRequestStream =>
      _connectionRequestController.stream;
  Device? get localDevice => _localDevice;
  List<Device> get devices => _discoveredDevices.values.toList();
  bool get isRunning => _isRunning;

  /// This device's certificate for requests to other devices; null before
  /// [initialize].
  SecurityContext? get clientContext => _clientContext;

  /// The fingerprint discovery heard from [id] at [address]: a request that
  /// claims to be that device must come with that certificate.
  String? _expectedFingerprint(String id, String address) {
    final d = _discoveredDevices[id];
    if (d == null || d.versionMismatch || d.ip != address || d.fingerprint.isEmpty) {
      return null;
    }
    return d.fingerprint;
  }

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// يُمرِّر SettingsService لقراءة إعدادات Share في runtime
  void setSettings(SettingsService settings) {
    if (identical(_settings, settings)) {
      return;
    }
    _settings = settings;
    // Turning the folder off ends every agreement at once, not at the next request.
    settings.addListener(() {
      if (!settings.sharedFolderEnabled) {
        _share.revokeAll();
      }
    });
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isRunning) {
      return;
    }
    final name = await DeviceManager.getDeviceName('Apex Device');
    final type = await DeviceManager.getDeviceTypePrecise();
    final ip = await _getLocalIp();
    final hostname = await DeviceManager.getHostname();
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = 'local-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
    }
    // The app's private folder, never Downloads or a shared one.
    final folder = identityFolder(await getApplicationSupportDirectory());
    final identity = _identity ??= await DeviceIdentity.loadOrCreate(folder);
    _clientContext ??= identity.clientContext();
    if (_serverContext == null) {
      _serverContext = identity.serverContext();
      _peerTrust = PeerTrust(_serverContext!);
    }
    await _pins.useFile(File('${folder.path}/pins.json'));
    _localDevice = Device(
      id: deviceId,
      name: name,
      type: type,
      ip: ip,
      hostname: hostname,
      fingerprint: identity.fingerprint,
      certificate: identity.certificate,
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

    _discoveryService = DiscoveryService(
      isShareEnabled: () => _settings?.sharedFolderEnabled ?? false,
    );
    _discoveryService!.onDeviceFound.listen((device) {
      if (TransferProgressService().isTransferring) {
        return;
      }
      // Never merged by name: its address must not reach a working record.
      if (device.versionMismatch) {
        _discoveredDevices[device.id] = device;
        _devicesController.add(devices);
        return;
      }
      // Its requests to this device can only finish the handshake once its
      // certificate is trusted; the doors then check it is the one it claims.
      final certificate = device.certificate;
      if (certificate != null) {
        _peerTrust?.trust(certificate);
      }
      mergeFound(_discoveredDevices, device);
      _devicesController.add(devices);
    });
    _discoveryService!.onDeviceLost.listen((id) {
      if (TransferProgressService().isTransferring) {
        return;
      }
      _discoveredDevices.remove(id);
      _nearby.forget(id);
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

  /// Clears the list, reads this device's address again and reopens the
  /// discovery socket, without stopping the transfer server.
  Future<void> refreshDiscovery() async {
    if (TransferProgressService().isTransferring) {
      return;
    }
    _discoveredDevices.clear();
    _nearby.connectedEndpoints.clear();
    _devicesController.add([]);
    final ip = await _getLocalIp();
    _localDevice = _localDevice?.copyWith(ip: ip);
    await _discoveryService?.restart();
  }

  /// إرسال UDP unicast مباشر لجهاز محدد بـ IP (للأجهزة المثبتة)
  void pingDevice(Device device) {
    _discoveryService?.pingDevice(device);
  }

  /// تحديث اسم الجهاز المحلي فوراً وحفظه في SharedPreferences
  Future<void> updateDeviceName(String newName) async {
    if (newName.trim().isEmpty) {
      return;
    }
    final trimmed = newName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_display_name', trimmed);
    _localDevice = _localDevice?.copyWith(name: trimmed);
    // إعادة البث فوراً بالاسم الجديد
    _discoveryService?.forceBroadcast();
  }

  // ─── HTTP Server ───────────────────────────────────────────────────────────

  Future<void> _startHttpServer() async {
    // TLS both ways: every client must show its certificate too.
    _httpServer = await HttpServer.bindSecure(InternetAddress.anyIPv4, 0, _serverContext!,
        requestClientCertificate: true);
    _httpPort = _httpServer!.port;
    _localDevice = _localDevice!.copyWith(port: _httpPort);
    // A failed handshake (a stranger's certificate) ends that connection only.
    _httpServer!.listen(_handleRequest,
        onError: (Object e) => ApexLogger.instance.log('HTTP', 'Handshake: $e', LogLevel.warning));
    ApexLogger.instance.log('HTTP', '✅ Port: $_httpPort', LogLevel.success);
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      if (await _receive.handle(req)) {
        // تم التعامل مع طلب استقبال
      } else if (await _chat.handle(req)) {
        // رسالة محادثة
      } else if (await _share.handle(req)) {
        // تم التعامل مع طلب Share
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

  Future<({ChatOutcome outcome, String? token})> _sendChat(
      String text, Device target, String? token) async {
    if (target.versionMismatch) {
      return (outcome: ChatOutcome.updateRequired, token: null);
    }
    // Chat goes over the local network only, not over Nearby.
    if (!target.isMdns) {
      return (outcome: ChatOutcome.failed, token: null);
    }
    return _send.sendChat(text, target, token);
  }

  Future<SendOutcome> sendFile(String filePath, Device target) =>
      sendFileWithName(filePath, _extractFileName(filePath), target);

  Future<SendOutcome> sendFileWithName(
      String filePath, String fileName, Device target) async {
    if (target.versionMismatch) {
      return SendOutcome.updateRequired;
    }
    final f = File(filePath);
    if (!await f.exists()) {
      return SendOutcome.failed;
    }
    final files = [(path: filePath, name: fileName, size: await f.length())];
    return _sendBatch(files, target);
  }

  Future<SendOutcome> sendFiles(List<String> filePaths, Device target) async {
    if (target.versionMismatch) {
      return SendOutcome.updateRequired;
    }
    if (filePaths.isEmpty) {
      return SendOutcome.failed;
    }

    return sendNamedFiles(
        [for (final path in filePaths) (path: path, name: _extractFileName(path))], target);
  }

  /// Files sent under names other than their own: an app's APK is always
  /// "base.apk" in a read-only system folder, so it cannot be renamed there.
  Future<SendOutcome> sendNamedFiles(
      List<({String path, String name})> named, Device target) async {
    if (target.versionMismatch) {
      return SendOutcome.updateRequired;
    }
    final files = <({String path, String name, int size})>[];
    for (final n in named) {
      final f = File(n.path);
      if (!await f.exists()) {
        continue;
      }
      files.add((path: n.path, name: n.name, size: await f.length()));
    }
    if (files.isEmpty) {
      return SendOutcome.failed;
    }

    return _sendBatch(files, target);
  }

  /// Every send over the network goes through the chat, so it shows there as
  /// a line, whichever button started it; Nearby has no chat.
  Future<SendOutcome> _sendBatch(List<OutgoingFile> files, Device target) {
    if (_isAndroid && target.isNearby) {
      return _nearby.sendBatch(files, target);
    }
    return chat.sendFiles(target, [for (final f in files) ChatFile(f.name, f.size, f.path)]);
  }

  /// Android saves through MediaStore; other systems move the file into the
  /// category folder without replacing an existing one.
  Future<String> _placeReceived(File temp, String name) async {
    if (_isAndroid) {
      final saved = await PathUtils.saveToPublicDownloads(name, temp.path);
      if (saved == null) {
        throw FileSystemException('Could not save to Downloads', name);
      }
      try {
        await temp.delete();
      } catch (_) {}
      return saved;
    }
    final folder = Directory(await PathUtils.getCategoryPath(name));
    return (await moveIntoFolder(temp, folder, name)).path;
  }

  // ─── Nearby incoming connection ────────────────────────────────────────────

  void handleIncomingConnectionInitiated(String endpointId, String endpointName) async {
    final accepted = await _nearby.answerConnection(endpointId, endpointName);
    ApexLogger.instance.log('NEARBY', '${accepted ? 'Accepted' : 'Refused'}: $endpointId',
        accepted ? LogLevel.success : LogLevel.warning);
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
          if (name.contains('wlan') ||
              name.contains('wifi') ||
              name.contains('wl')) {
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
        // Only shown on "My Device": discovery goes out on every network.
        const virtual = ['vethernet', 'virtual', 'vmware', 'vbox', 'docker', 'br-', 'virbr',
            'tailscale', 'zerotier', 'tun', 'tap', 'wsl'];
        for (final iface in interfaces) {
          final name = iface.name.toLowerCase();
          if (virtual.any(name.contains)) {
            continue;
          }
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('192.168.137.')) {
              return addr.address;
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

  /// استخراج اسم الملف من المسار بشكل يعمل على كل الأنظمة
  static String _extractFileName(String path) {
    // يدعم / و \ كفاصل مسارات
    final lastSep = path.lastIndexOf(RegExp(r'[/\\]'));
    return lastSep == -1 ? path : path.substring(lastSep + 1);
  }
}
