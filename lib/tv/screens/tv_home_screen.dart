import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/apex_core.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../services/desktop_notification_service.dart';
import '../../services/file_storage_service.dart';
import '../../services/pinned_devices_service.dart';
import '../../services/settings_service.dart';
import '../widgets/tabs/tv_files_tab.dart';
import '../widgets/tabs/tv_receive_tab.dart';
import '../widgets/tabs/tv_send_tab.dart';
import '../widgets/tv_details_panel.dart';

class TVHomeScreen extends StatefulWidget {
  final SettingsService settings;
  const TVHomeScreen({required this.settings, super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  int _selectedIndex = 0;

  // ─── Focus nodes — كلها محكومة يدوياً ────────────────────────────────────
  final FocusNode _sendFocus = FocusNode(debugLabel: 'nav-send');
  final FocusNode _receiveFocus = FocusNode(debugLabel: 'nav-receive');
  final FocusNode _filesFocus = FocusNode(debugLabel: 'nav-files');
  final FocusNode _settingsFocus = FocusNode(debugLabel: 'nav-settings');
  final FocusNode _refreshFocus = FocusNode(debugLabel: 'nav-refresh');

  // FocusNode لأول عنصر في كل tab
  final FocusNode _sendContentFocus = FocusNode(debugLabel: 'send-content');
  final FocusNode _receiveContentFocus =
      FocusNode(debugLabel: 'receive-content');
  final FocusNode _filesContentFocus = FocusNode(debugLabel: 'files-content');

  // ترتيب عناصر الـ Sidebar للتنقل بالأسهم
  late final List<FocusNode> _sidebarNodes;

  final List<Device> _devices = [];
  Device? _localDevice;
  bool _isRunning = false;

  // ─── Pinned devices ────────────────────────────────────────────────────────
  final _pinnedService = PinnedDevicesService();
  List<Device> _pinnedDevices = [];

  bool _isPinned(String deviceId) =>
      _pinnedDevices.any((d) => d.id == deviceId);

  Future<void> _pinDevice(Device device) async {
    await _pinnedService.pin(device);
    final updated = await _pinnedService.load();
    if (mounted) {
      setState(() => _pinnedDevices = updated);
    }
  }

  Future<void> _unpinDevice(String deviceId) async {
    await _pinnedService.unpin(deviceId);
    final updated = await _pinnedService.load();
    if (mounted) {
      setState(() => _pinnedDevices = updated);
    }
  }

  @override
  void initState() {
    super.initState();
    _sidebarNodes = [
      _sendFocus,
      _receiveFocus,
      _filesFocus,
      _settingsFocus,
      _refreshFocus
    ];
    _initializeSystem();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _sendFocus.requestFocus());
    _pinnedService.load().then((list) {
      if (mounted) {
        setState(() => _pinnedDevices = list);
      }
    });
  }

  Future<void> _initializeSystem() async {
    final core = ApexCore.instance;
    core.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices
            ..clear()
            ..addAll(devices);
        });
      }
    });
    core.fileReceivedStream.listen((e) {
      DesktopNotificationService.instance
          .showFileReceived(e.fileName, e.fromDevice);
      if (mounted) {
        setState(() => _selectedIndex = 2);
      }
    });
    setState(() {
      _localDevice = core.localDevice;
      _isRunning = core.isRunning;
    });
    await core.start();
    if (mounted) {
      setState(() => _isRunning = core.isRunning);
    }
  }

  Future<void> _restartCore() async {
    await ApexCore.instance.stop();
    await ApexCore.instance.start();
    if (mounted) {
      setState(() => _isRunning = ApexCore.instance.isRunning);
    }
  }

  @override
  void dispose() {
    for (final n in [
      ..._sidebarNodes,
      _sendContentFocus,
      _receiveContentFocus,
      _filesContentFocus
    ]) {
      n.dispose();
    }
    super.dispose();
  }

  void _moveToContent() {
    switch (_selectedIndex) {
      case 0:
        _sendContentFocus.requestFocus();
      case 1:
        _receiveContentFocus.requestFocus();
      case 2:
        _filesContentFocus.requestFocus();
      default:
        _sendContentFocus.requestFocus();
    }
  }

  void _moveToSidebar() {
    switch (_selectedIndex) {
      case 0:
        _sendFocus.requestFocus();
      case 1:
        _receiveFocus.requestFocus();
      case 2:
        _filesFocus.requestFocus();
      default:
        _sendFocus.requestFocus();
    }
  }

  // تنقل الـ Sidebar بالأسهم — مغلق تماماً لا يخرج
  // RTL: يسار → محتوى، يمين → مسدود
  // LTR: يمين → محتوى، يسار → مسدود
  KeyEventResult _handleSidebarKey(FocusNode current, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final toContentKey =
        isRtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final blockedKey =
        isRtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;

    final idx = _sidebarNodes.indexOf(current);

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (idx < _sidebarNodes.length - 1) {
        _sidebarNodes[idx + 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        _sidebarNodes[idx - 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == toContentKey) {
      _moveToContent();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == blockedKey) {
      return KeyEventResult.handled; // لا يخرج للخارج
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(l10n.exitApp),
              content: Text(l10n.exitConfirmation),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel)),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.exit,
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (shouldExit == true && context.mounted) {
            exit(0);
          }
        }
      },
      child: Scaffold(
        body: Row(children: [
          // ─── Sidebar ──────────────────────────────────────────────────
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
              border: Border(
                  right: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              )),
            ),
            child: SafeArea(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App name
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/ico.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Apex Transfer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: isDark ? Colors.white : Colors.black,
                                  )),
                              Text('TV Mode',
                                  style: TextStyle(fontSize: 11, color: color)),
                            ]),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    // ─── Nav items ─────────────────────────────────────────
                    _TVNavItem(
                      icon: Icons.send_rounded,
                      label: l10n.send,
                      selected: _selectedIndex == 0,
                      focusNode: _sendFocus,
                      onSelect: () => setState(() => _selectedIndex = 0),
                      onMoveToContent: _moveToContent,
                      onKey: (e) => _handleSidebarKey(_sendFocus, e),
                    ),
                    _TVNavItem(
                      icon: Icons.smartphone_rounded,
                      label: l10n.receive,
                      selected: _selectedIndex == 1,
                      focusNode: _receiveFocus,
                      onSelect: () => setState(() => _selectedIndex = 1),
                      onMoveToContent: _moveToContent,
                      onKey: (e) => _handleSidebarKey(_receiveFocus, e),
                    ),
                    _TVNavItem(
                      icon: Icons.folder_rounded,
                      label: l10n.files,
                      selected: _selectedIndex == 2,
                      focusNode: _filesFocus,
                      onSelect: () => setState(() => _selectedIndex = 2),
                      onMoveToContent: _moveToContent,
                      onKey: (e) => _handleSidebarKey(_filesFocus, e),
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Divider(height: 1),
                    ),
                    // ─── Settings زر ──────────────────────────────────────
                    _TVNavItem(
                      icon: Icons.settings_rounded,
                      label: l10n.settings,
                      selected: false,
                      focusNode: _settingsFocus,
                      onSelect: () =>
                          showTVDetailsPanel(context, widget.settings),
                      onMoveToContent: () {},
                      onKey: (e) => _handleSidebarKey(_settingsFocus, e),
                    ),
                    // ─── Refresh زر ───────────────────────────────────────
                    _TVNavItem(
                      icon: Icons.refresh_rounded,
                      label: l10n.restartingSystem,
                      selected: false,
                      focusNode: _refreshFocus,
                      onSelect: _restartCore,
                      onMoveToContent: () {},
                      onKey: (e) => _handleSidebarKey(_refreshFocus, e),
                    ),
                    const Spacer(),
                  ]),
            ),
          ),
          // ─── Content ──────────────────────────────────────
          Expanded(child: _buildContent()),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return TVSendTab(
          devices: _devices,
          pinnedDevices: _pinnedDevices,
          isRunning: _isRunning,
          isPinned: _isPinned,
          onPin: _pinDevice,
          onUnpin: _unpinDevice,
          onBackToSidebar: _moveToSidebar,
          contentFocusNode: _sendContentFocus,
        );
      case 1:
        return TVReceiveTab(
          localDevice: _localDevice,
          isRunning: _isRunning,
          onBackToSidebar: _moveToSidebar,
          contentFocusNode: _receiveContentFocus,
        );
      default:
        return TVFilesTab(
          getReceivedFiles: () => FileStorageService().getReceivedFiles(),
          onBackToSidebar: _moveToSidebar,
          contentFocusNode: _filesContentFocus,
        );
    }
  }
}

// ─── TV Nav Item ──────────────────────────────────────────────────────────────

class _TVNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final VoidCallback onMoveToContent;
  final KeyEventResult Function(KeyEvent) onKey;

  const _TVNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
    required this.onMoveToContent,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          onSelect();
          onMoveToContent();
          return KeyEventResult.handled;
        }
        return onKey(event);
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: GestureDetector(
            onTap: () {
              onSelect();
              onMoveToContent();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: isDark ? 0.2 : 0.12)
                    : hasFocus
                        ? color.withValues(alpha: 0.08)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: hasFocus && !selected
                    ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
                    : null,
              ),
              child: Row(children: [
                Icon(icon,
                    size: 22,
                    color: selected || hasFocus
                        ? color
                        : (isDark ? Colors.white54 : Colors.black45)),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected || hasFocus
                          ? color
                          : (isDark ? Colors.white70 : Colors.black54),
                    )),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
