import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/apex_core.dart';
import '../../models/device.dart';
import '../../services/clipboard_monitor_service.dart';
import '../../services/file_operations_service.dart';
import '../../services/file_storage_service.dart';
import '../../services/settings_service.dart';
import '../../services/update_service.dart';

/// Controller مركزي لـ HomeScreen — يدير الحالة والمنطق بمعزل عن الـ UI
class HomeController extends ChangeNotifier {
  final SettingsService settings;

  HomeController({required this.settings});

  // ─── State ──────────────────────────────────────────────────────────────────

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  List<Device> _devices = [];
  List<Device> get devices => _devices;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _pendingSinanFilePath;
  String? get pendingSinanFilePath => _pendingSinanFilePath;

  List<String>? _pendingSharedFiles;
  List<String>? get pendingSharedFiles => _pendingSharedFiles;

  // Clipboard state (Windows only)
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

  final _fileOpsService = FileOperationsService();

  static const _shareChannel = MethodChannel('com.apex.core/share');

  // ─── Callbacks for UI-only actions (sheets, navigation) ─────────────────────
  // These are set by the UI layer since they need BuildContext

  void Function(FileReceivedEvent event)? onFileReceived;
  void Function(ConnectionRequest request)? onConnectionRequest;
  void Function(String message)? onError;
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
    if (!kIsWeb && Platform.isAndroid) {
      Future.delayed(const Duration(seconds: 3), _initUpdateService);
    }
  }

  void _listenToStreams() {
    ApexCore.instance.devicesStream.listen((d) {
      _devices = d;
      notifyListeners();
    });
    ApexCore.instance.fileReceivedStream.listen((e) {
      _currentIndex = 2;
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
      ApexCore.instance.setNetworkMode(settings.networkMode);
      await ApexCore.instance.start();
      _isRunning = true;
      notifyListeners();
    } catch (e) {
      onError?.call('System start failed');
    }
  }

  Future<void> stopSystem() async {
    await ApexCore.instance.stop();
    _isRunning = false;
    _devices.clear();
    notifyListeners();
  }

  Future<void> restartSystem() async {
    ApexCore.instance.setNetworkMode(settings.networkMode);
    await stopSystem();
    await Future.delayed(const Duration(milliseconds: 400));
    await _startSystem();
  }

  /// تحديث خفيف — يبث وجود الجهاز فوراً بدون إعادة تشغيل
  void refreshDiscovery() {
    ApexCore.instance.refreshDiscovery();
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

  // ─── Clipboard monitor (Windows only) ───────────────────────────────────────

  void _initClipboardMonitor() {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }
    ClipboardMonitorService.instance.initialize();
    _clipboardSub = ClipboardMonitorService.instance.stream.listen((item) {
      _pendingClipboardItem = item;
      if (item != null) {
        // انتقل تلقائياً لتبويب الإرسال لعرض البانر
        _currentIndex = 0;
      }
      notifyListeners();
    });
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
    filesRefreshNotifier.dispose();
    super.dispose();
  }
}
