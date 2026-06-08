import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/apex_core.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/device.dart';
import '../services/desktop_notification_service.dart';
import '../services/file_storage_service.dart';
import '../services/settings_service.dart';
import '../widgets/tabs/receive_tab.dart';
import '../widgets/tabs/tv_files_tab.dart';
import '../widgets/tabs/tv_send_tab.dart';
import '../widgets/transfer_progress_overlay.dart';

class TVHomeScreen extends StatefulWidget {
  final SettingsService settings;
  const TVHomeScreen({required this.settings, super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  int _selectedIndex = 0;
  final FocusNode _sendFocus = FocusNode();
  final FocusNode _receiveFocus = FocusNode();
  final FocusNode _filesFocus = FocusNode();
  final List<Device> _devices = [];
  Device? _localDevice;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _sendFocus.requestFocus());
  }

  Future<void> _initializeSystem() async {
    final core = ApexCore.instance;

    core.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices.clear();
          _devices.addAll(devices);
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

  @override
  void dispose() {
    _sendFocus.dispose();
    _receiveFocus.dispose();
    _filesFocus.dispose();
    super.dispose();
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
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: TransferProgressOverlay(
          child: Row(
            children: [
              // ─── Sidebar ───────────────────────────────────────────────
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFF5F5F7),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App name
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.share_rounded,
                                color: color, size: 22),
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
                            ],
                          ),
                        ]),
                      ),
                      // Status
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isRunning
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _isRunning ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isRunning ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isRunning ? Colors.green : Colors.grey,
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Nav items
                      _TVNavItem(
                          icon: Icons.send_rounded,
                          label: l10n.send,
                          selected: _selectedIndex == 0,
                          focusNode: _sendFocus,
                          onSelect: () => setState(() => _selectedIndex = 0),
                          nextFocus: _receiveFocus,
                          prevFocus: null),
                      _TVNavItem(
                          icon: Icons.smartphone_rounded,
                          label: l10n.receive,
                          selected: _selectedIndex == 1,
                          focusNode: _receiveFocus,
                          onSelect: () => setState(() => _selectedIndex = 1),
                          nextFocus: _filesFocus,
                          prevFocus: _sendFocus),
                      _TVNavItem(
                          icon: Icons.folder_rounded,
                          label: l10n.files,
                          selected: _selectedIndex == 2,
                          focusNode: _filesFocus,
                          onSelect: () => setState(() => _selectedIndex = 2),
                          nextFocus: null,
                          prevFocus: _receiveFocus),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Text(
                          l10n.pressMenuForSettings,
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ─── Content ────────────────────────────────────────────────
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return TVSendTab(devices: _devices, isRunning: _isRunning);
      case 1:
        return ReceiveTab(localDevice: _localDevice, isRunning: _isRunning);
      default:
        return TVFilesTab(
            getReceivedFiles: () => FileStorageService().getReceivedFiles());
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
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;

  const _TVNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
    required this.nextFocus,
    required this.prevFocus,
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
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            nextFocus != null) {
          nextFocus!.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
            prevFocus != null) {
          prevFocus!.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(12),
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
