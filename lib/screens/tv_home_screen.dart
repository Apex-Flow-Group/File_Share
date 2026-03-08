import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/apex_core.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../services/file_storage_service.dart';
import '../services/settings_service.dart';
import '../widgets/tabs/receive_tab.dart';
import '../widgets/tabs/tv_files_tab.dart';
import '../widgets/tabs/tv_send_tab.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendFocus.requestFocus();
    });
  }

  Future<void> _initializeSystem() async {
    final core = ApexCore.instance;
    
    // Check WiFi connection
    if (!await _checkWiFiConnection()) {
      if (mounted) {
        _showWiFiDialog();
      }
      return;
    }
    
    // Listen to devices
    core.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices.clear();
          _devices.addAll(devices);
        });
      }
    });
    
    // Update local device
    setState(() {
      _localDevice = core.localDevice;
      _isRunning = core.isRunning;
    });
    
    // Start the system
    await core.start();
    
    // Update running status after start
    if (mounted) {
      setState(() => _isRunning = core.isRunning);
    }
  }

  Future<bool> _checkWiFiConnection() async {
    try {
      final localDevice = ApexCore.instance.localDevice;
      return localDevice != null && localDevice.ip != '192.168.1.100';
    } catch (e) {
      return false;
    }
  }

  void _showWiFiDialog() {
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.wifi_off,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          l10n.notConnectedToWiFi,
          textAlign: TextAlign.center,
        ),
        content: Text(
          l10n.mustConnectToWiFi,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openWiFiSettings();
            },
            icon: const Icon(Icons.wifi),
            label: Text(l10n.openWiFiSettings),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openHotspotSettings();
            },
            icon: const Icon(Icons.router),
            label: Text(l10n.createHotspot),
          ),
        ],
      ),
    );
  }

  Future<void> _openWiFiSettings() async {
    try {
      await Process.run('am', [
        'start',
        '-a', 'android.settings.WIFI_SETTINGS',
      ]);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _openHotspotSettings() async {
    try {
      await Process.run('am', [
        'start',
        '-a', 'android.settings.TETHER_SETTINGS',
      ]);
    } catch (e) {
      // Ignore
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.exitApp, style: const TextStyle(fontSize: 20)),
              content: Text(l10n.exitConfirmation, style: const TextStyle(fontSize: 18)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.exit, style: const TextStyle(fontSize: 18, color: Colors.red)),
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
        body: Row(
          children: [
            // Sidebar Navigation
            Container(
              width: 280,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Apex Transfer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Navigation Items
                  _buildNavItem(
                    icon: Icons.send_rounded,
                    label: l10n.send,
                    index: 0,
                    focusNode: _sendFocus,
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(
                    icon: Icons.download_rounded,
                    label: l10n.receive,
                    index: 1,
                    focusNode: _receiveFocus,
                  ),
                  const SizedBox(height: 8),
                  _buildNavItem(
                    icon: Icons.folder_rounded,
                    label: l10n.files,
                    index: 2,
                    focusNode: _filesFocus,
                  ),
                  const Spacer(),
                  // Settings hint
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.pressMenuForSettings,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required FocusNode focusNode,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            if (index == 0) {
              _receiveFocus.requestFocus();
            }
            if (index == 1) {
              _filesFocus.requestFocus();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (index == 1) {
              _sendFocus.requestFocus();
            }
            if (index == 2) {
              _receiveFocus.requestFocus();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.space) {
            setState(() => _selectedIndex = index);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : null,
              border: hasFocus 
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                icon,
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 18,
                ),
              ),
              onTap: () => setState(() => _selectedIndex = index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return TVSendTab(devices: _devices, isRunning: _isRunning);
    } else if (_selectedIndex == 1) {
      return ReceiveTab(localDevice: _localDevice, isRunning: _isRunning);
    } else {
      return TVFilesTab(
        getReceivedFiles: () => FileStorageService().getReceivedFiles(),
      );
    }
  }
}
