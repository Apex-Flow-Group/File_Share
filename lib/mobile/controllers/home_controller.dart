import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/apex_core.dart';
import '../../core/start_guard.dart';
import '../../models/device.dart';
import '../../services/clipboard_monitor_service.dart';
import '../../services/file_operations_service.dart';
import '../../services/file_storage_service.dart';
import '../../services/pinned_devices_service.dart';
import '../../services/settings_service.dart';
import '../../services/update_service.dart';
import '../../utils/apex_logger.dart';

/// Controller مركزي لـ HomeScreen — يدير الحالة والمنطق بمعزل عن الـ UI
class HomeController extends ChangeNotifier {
  final SettingsService settings;

  HomeController({required this.settings});

  // ─── State ──────────────────────────────────────────────────────────────────

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  List<Device> _devices = [];
  List<Device> get devices => _devices;

  List<Device> _pinnedDevices = [];
  /// Each with the fingerprint pinned at its last acceptance, so one that
  /// discovery has not heard yet can still be sent to (owner decision).
  List<Device> get pinnedDevices => [for (final d in _pinnedDevices) ApexCore.instance.withPinnedKey(d)];

  final _pinnedService = PinnedDevicesService();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// False while the first start is still running: that is not a failure.
  bool _startFailed = false;
  bool get startFailed => _startFailed;

  String? _pendingSinanFilePath;
  String? get pendingSinanFilePath => _pendingSinanFilePath;

  List<String>? _pendingSharedFiles;
  List<String>? get pendingSharedFiles => _pendingSharedFiles;

  // Clipboard state (Windows + Linux)
  ClipboardItem? _pendingClipboardItem;
  ClipboardItem? get pendingClipboardItem => _pendingClipboardItem;
  StreamSubscription<ClipboardItem?>? _clipboardSub;

  // Files tab state
  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  Set<String> _selectedFiles = {};
  Set<String> get selectedFiles => _selectedFiles;

  String _sortBy = 'date';
  String get sortBy => _sortBy;

  bool _sortAscending = false;
  bool get sortAscending => _sortAscending;

  final filesRefreshNotifier = ValueNotifier<int>(0);

  final _fileOpsService = FileOperationsService(senders: ApexCore.instance.senders);

  static const _shareChannel = MethodChannel('com.apex.core/share');

  // ─── Callbacks for UI-only actions (sheets, navigation) ─────────────────────
  // These are set by the UI layer since they need BuildContext

  void Function(FileReceivedEvent event)? onFileReceived;
  void Function(ConnectionRequest request)? onConnectionRequest;
  void Function()? onStartFailed;
  void Function()? onUpdateAvailable;
  void Function()? onUpdateReady;

  // ─── Initialization ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _checkIncomingSinanFile();
    _checkIncomingSharedFiles();
    _listenToStreams();
    _initClipboardMonitor();
    await _startSystem();
    await _loadSortPreference();
    await _loadPinnedDevices();
    if (!kIsWeb && Platform.isAndroid) {
      Future.delayed(const Duration(seconds: 3), _initUpdateService);
    }
  }

  void _listenToStreams() {
    ApexCore.instance.devicesStream.listen((d) {
      _devices = d;
      notifyListeners();
    });
    // A received file stays where the user is (owner decision): its sheet
    // opens the sender's chat.
    ApexCore.instance.fileReceivedStream.listen((e) {
      filesRefreshNotifier.value++;
      notifyListeners();

      // اعرض الإشعار فقط عند آخر ملف في الدفعة
      if (e.isLastInBatch) {
        onFileReceived?.call(e);
      }
    });
    ApexCore.instance.connectionRequestStream.listen((r) {
      onConnectionRequest?.call(r);
    });
  }

  // ─── System control ─────────────────────────────────────────────────────────

  Future<void> _startSystem() async {
    try {
      ApexCore.instance.setSettings(settings);
      await ApexCore.instance.start();
      _isRunning = true;
      _startFailed = false;
    } catch (e) {
      ApexLogger.instance.log('CORE', 'Start: $e', LogLevel.error);
      _startFailed = true;
      onStartFailed?.call();
    }
    notifyListeners();
  }

  Future<void> retryStart() async {
    _startFailed = false;
    notifyListeners();
    await _startSystem();
  }

  Future<void> stopSystem() async {
    await ApexCore.instance.stop();
    _isRunning = false;
    _devices.clear();
    notifyListeners();
  }

  /// Pings favorites after the socket is reopened, so the ping is not lost.
  Future<void> refreshDiscovery() async {
    switch (findDevicesAction(isRunning: _isRunning, startFailed: _startFailed)) {
      case FindDevices.wait:
        return;
      case FindDevices.start:
        return retryStart();
      case FindDevices.search:
        await ApexCore.instance.refreshDiscovery();
    }
    _pingPinnedDevices();
  }

  // ─── Pinned Devices ──────────────────────────────────────────────────────────

  Future<void> _loadPinnedDevices() async {
    _pinnedDevices = await _pinnedService.load();
    notifyListeners();
  }

  Future<void> pinDevice(Device device) async {
    await _pinnedService.pin(device);
    _pinnedDevices = await _pinnedService.load();
    notifyListeners();
  }

  Future<void> unpinDevice(String deviceId) async {
    await _pinnedService.unpin(deviceId);
    _pinnedDevices = await _pinnedService.load();
    notifyListeners();
  }

  bool isPinned(String deviceId) => _pinnedDevices.any((d) => d.id == deviceId);

  /// يرسل UDP ping مباشرة لـ IPs الأجهزة المثبتة
  void _pingPinnedDevices() {
    for (final d in _pinnedDevices) {
      if (d.ip.isNotEmpty) {
        ApexCore.instance.pingDevice(d);
      }
    }
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void setCurrentIndex(int index) {
    _currentIndex = index;
    if (index != 2 && _isSelectionMode) {
      exitSelectionMode();
    }
    notifyListeners();
  }

  // ─── Files operations ───────────────────────────────────────────────────────

  Future<List<FileSystemEntity>> getReceivedFiles() =>
      FileStorageService().getReceivedFiles();

  void enterSelectionMode(String path) {
    _isSelectionMode = true;
    _selectedFiles.add(path);
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedFiles.clear();
    notifyListeners();
  }

  void toggleFileSelection(String path) {
    if (_selectedFiles.contains(path)) {
      _selectedFiles.remove(path);
      if (_selectedFiles.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedFiles.add(path);
    }
    notifyListeners();
  }

  Future<void> selectAllFiles() async {
    final files = await getReceivedFiles();
    _selectedFiles = files.map((f) => f.path).toSet();
    notifyListeners();
  }

  Future<int> deleteSelectedFiles() async {
    final count = await _fileOpsService.deleteFiles(
      _selectedFiles,
      deleteFromFolder: true,
    );
    exitSelectionMode();
    return count;
  }

  Future<int> deleteSelectedFilesWithOption(bool deleteFromDevice) async {
    final count = await _fileOpsService.deleteFiles(
      _selectedFiles,
      deleteFromFolder: deleteFromDevice,
    );
    exitSelectionMode();
    return count;
  }

  // ─── Sort ───────────────────────────────────────────────────────────────────

  void setSortBy(String value) {
    _sortBy = value;
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  Future<void> _loadSortPreference() async {
    final prefs = await settings.getPreferences();
    _sortBy = prefs['sortBy'] ?? 'date';
    _sortAscending = prefs['sortAscending'] ?? false;
    notifyListeners();
  }

  Future<void> saveSortPreference() async {
    await settings.savePreference('sortBy', _sortBy);
    await settings.savePreference('sortAscending', _sortAscending);
  }

  // ─── Pending files ──────────────────────────────────────────────────────────

  void clearPendingSinanFile() {
    _pendingSinanFilePath = null;
    notifyListeners();
  }

  void clearPendingSharedFiles() {
    _pendingSharedFiles = null;
    notifyListeners();
  }

  void setPendingSinanFile(String path) {
    _pendingSinanFilePath = path;
    _currentIndex = 0;
    notifyListeners();
  }

  void setPendingSharedFiles(List<String> paths) {
    _pendingSharedFiles = paths;
    _currentIndex = 0;
    notifyListeners();
  }

  // ─── Clipboard monitor (Windows + Linux) ────────────────────────────────────

  void _initClipboardMonitor() {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux)) {
      return;
    }
    ClipboardMonitorService.instance.initialize();
    _applyClipboardSetting();
    settings.addListener(_applyClipboardSetting);
    _clipboardSub = ClipboardMonitorService.instance.stream.listen((item) {
      _pendingClipboardItem = item;
      notifyListeners();
    });
  }

  void _applyClipboardSetting() {
    ClipboardMonitorService.instance.setEnabled(settings.clipboardMonitorEnabled);
  }

  void clearPendingClipboardItem() {
    _pendingClipboardItem = null;
    ClipboardMonitorService.instance.clearItem();
    notifyListeners();
  }

  // ─── Incoming files (platform channels) ─────────────────────────────────────

  void _checkIncomingSinanFile() async {
    const channel = MethodChannel('com.apex.core/sinan');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onSinanFileReceived') {
        final path = call.arguments as String?;
        if (path != null) {
          setPendingSinanFile(path);
        }
      }
    });
    try {
      final path = await channel.invokeMethod<String>('getPendingSinanFile');
      if (path != null) {
        setPendingSinanFile(path);
      }
    } catch (_) {}
  }

  void _checkIncomingSharedFiles() async {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFilesReceived') {
        final paths = (call.arguments as List?)?.cast<String>();
        if (paths != null && paths.isNotEmpty) {
          setPendingSharedFiles(paths);
        }
      }
    });
    try {
      final paths =
          await _shareChannel.invokeMethod<List>('getPendingSharedFiles');
      final list = paths?.cast<String>();
      if (list != null && list.isNotEmpty) {
        setPendingSharedFiles(list);
      }
    } catch (_) {}
  }

  // ─── Update service ─────────────────────────────────────────────────────────

  void _initUpdateService() {
    UpdateService.instance.stateStream.listen((updateState) {
      switch (updateState) {
        case UpdateState.available:
          onUpdateAvailable?.call();
        case UpdateState.readyToInstall:
          onUpdateReady?.call();
        case UpdateState.downloading:
        case UpdateState.waitingForIdle:
        case UpdateState.idle:
          break;
      }
    });
    UpdateService.instance.checkForUpdate();
  }

  // ─── File operations service (for opening files) ────────────────────────────

  FileOperationsService get fileOpsService => _fileOpsService;

  @override
  void dispose() {
    _clipboardSub?.cancel();
    settings.removeListener(_applyClipboardSetting);
    filesRefreshNotifier.dispose();
    super.dispose();
  }
}
