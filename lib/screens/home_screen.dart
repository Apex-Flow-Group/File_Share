import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/apex_core.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/device.dart';
import '../services/file_operations_service.dart';
import '../services/file_storage_service.dart';
import '../services/settings_service.dart';
import '../widgets/tabs/files_tab.dart';
import '../widgets/tabs/receive_tab.dart';
import '../widgets/tabs/send_tab.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  const HomeScreen({required this.settings, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Device> _devices = [];
  bool _isRunning = false;
  final _fileOpsService = FileOperationsService();
  final _filesTabKey = GlobalKey();
  String? _pendingSinanFilePath;

  // Files tab state
  bool _isSelectionMode = false;
  Set<String> _selectedFiles = {};
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _initSystem();
    _loadSortPreference();
  }

  Future<void> _initSystem() async {
    // Check for incoming .sinan file from Sinan Note
    _checkIncomingSinanFile();

    ApexCore.instance.devicesStream.listen((d) {
      if (mounted) {
        setState(() => _devices = d);
      }
    });
    ApexCore.instance.fileReceivedStream.listen((e) {
      if (mounted) {
        _showFileReceivedSheet(e);
        // Switch to files tab and force refresh
        setState(() => _currentIndex = 2);
      }
    });
    ApexCore.instance.connectionRequestStream.listen((r) {
      if (mounted) {
        _showConnectionRequestDialog(r);
      }
    });
    await _startSystem();
  }

  Future<void> _startSystem() async {
    try {
      ApexCore.instance.setNetworkMode(widget.settings.networkMode);
      await ApexCore.instance.start();
      if (mounted) {
        setState(() => _isRunning = true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnack(AppLocalizations.of(context).systemStartFailed);
      }
    }
  }

  Future<void> _stopSystem() async {
    await ApexCore.instance.stop();
    if (mounted) {
      setState(() { _isRunning = false; _devices.clear(); });
    }
  }

  Future<void> _restartSystem() async {
    ApexCore.instance.setNetworkMode(widget.settings.networkMode);
    await _stopSystem();
    await Future.delayed(const Duration(milliseconds: 400));
    await _startSystem();
  }

  void _checkIncomingSinanFile() async {
    const channel = MethodChannel('com.apex.core/sinan');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onSinanFileReceived') {
        final path = call.arguments as String?;
        if (path != null && mounted) {
          _handleSinanFile(path);
        }
      }
    });
    // Check for file that arrived before Flutter was ready
    try {
      final path = await channel.invokeMethod<String>('getPendingSinanFile');
      if (path != null && mounted) {
        _handleSinanFile(path);
      }
    } catch (_) {}
  }

  void _handleSinanFile(String filePath) {
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FloatingSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.note_add_rounded, size: 48, color: Colors.purple),
            const SizedBox(height: 12),
            Text(
              isAr ? 'ملاحظة من سنان' : 'Note from Sinan',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'تم استلام ملاحظة - أرسلها لجهاز آخر' : 'Note received - send it to another device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                  // Store path for user to pick device and send
                  _pendingSinanFilePath = filePath;
                },
                icon: const Icon(Icons.send_rounded),
                label: Text(isAr ? 'اختر جهاز للإرسال' : 'Choose device to send'),
                style: FilledButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs / Sheets ─────────────────────────────────────────────────────

  void _showFileReceivedSheet(FileReceivedEvent event) {
    final l10n = AppLocalizations.of(context);
    final displayPath = event.filePath
        .substring(0, event.filePath.lastIndexOf('/'))
        .replaceAll('/storage/emulated/0/', '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FloatingSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: Colors.green),
            const SizedBox(height: 12),
            Text(l10n.fileReceived,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text(event.fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(_formatSize(event.fileSize),
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 8),
            Text('${l10n.from}: ${event.fromDevice}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600])),
            Text('${l10n.savedIn}: $displayPath',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () { Navigator.pop(context); setState(() => _currentIndex = 2); },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(l10n.openFiles,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(l10n.close,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showConnectionRequestDialog(ConnectionRequest request) {
    final l10n = AppLocalizations.of(context);
    final sizeStr = request.fileSize > 0 ? _formatSize(request.fileSize) : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => SafeArea(
        child: _FloatingSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.file_download_rounded,
                    size: 36, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              Text(l10n.connectionRequest,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.acceptConnection,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Colors.blue.withValues(alpha: 0.15),
                          child: const Icon(Icons.smartphone_rounded,
                              color: Colors.blue, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(request.device.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.insert_drive_file_rounded,
                            size: 15, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(request.fileName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13))),
                      ]),
                      if (sizeStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(sizeStr,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                                fontSize: 13)),
                      ],
                    ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      request.onResponse(false);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(l10n.reject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      request.onResponse(true);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(l10n.accept),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600 && width < 900;
    final isDesktop = width >= 900;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: isDesktop
          ? _buildDesktopLayout()
          : isTablet
              ? _buildTabletLayout()
              : _buildMobileLayout(),
    );
  }

  // ─── Mobile layout ────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Scaffold(
      extendBody: true,
      body: _buildPage(_currentIndex),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        isRunning: _isRunning,
        onTap: (i) => setState(() {
          _currentIndex = i;
          if (i != 2 && _isSelectionMode) {
            _exitSelectionMode();
          }
        }),
        onSettingsTap: _openSettings,
        onAboutTap: _openAbout,
        onRestartTap: _restartSystem,
      ),
    );
  }

  // ─── Tablet layout ────────────────────────────────────────────────────────

  Widget _buildTabletLayout() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Navigation Rail
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: _currentIndex < 3 ? _currentIndex : 0,
                onDestinationSelected: (i) => setState(() {
                  _currentIndex = i;
                  if (i != 2 && _isSelectionMode) {
                    _exitSelectionMode();
                  }
                }),
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                backgroundColor: Colors.transparent,
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.send_outlined),
                    selectedIcon: const Icon(Icons.send_rounded),
                    label: Text(l10n.send),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.download_outlined),
                    selectedIcon: const Icon(Icons.download_rounded),
                    label: Text(l10n.receive),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.folder_outlined),
                    selectedIcon: const Icon(Icons.folder_rounded),
                    label: Text(l10n.files),
                  ),
                ],
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RailIconButton(
                            icon: Icons.restart_alt_rounded,
                            tooltip: l10n.restartingSystem,
                            onTap: _restartSystem,
                          ),
                          const SizedBox(height: 8),
                          _RailIconButton(
                            icon: Icons.settings_rounded,
                            tooltip: l10n.settings,
                            onTap: _openSettings,
                          ),
                          const SizedBox(height: 8),
                          _RailIconButton(
                            icon: Icons.info_outline_rounded,
                            tooltip: l10n.about,
                            onTap: _openAbout,
                          ),
                          const SizedBox(height: 8),
                          // status dot
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: _isRunning ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(child: _buildPage(_currentIndex)),
          ],
        ),
      ),
    );
  }

  // ─── Desktop layout ───────────────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.share_rounded, color: color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text('Apex Transfer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black,
                            )),
                      ],
                    ),
                  ),
                  // Status chip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isRunning
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 7, height: 7,
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
                  const SizedBox(height: 16),
                  // Nav items
                  _SidebarItem(
                    icon: Icons.send_rounded,
                    label: l10n.send,
                    selected: _currentIndex == 0,
                    onTap: () => setState(() {
                      _currentIndex = 0;
                      if (_isSelectionMode) {
                        _exitSelectionMode();
                      }
                    }),
                  ),
                  _SidebarItem(
                    icon: Icons.download_rounded,
                    label: l10n.receive,
                    selected: _currentIndex == 1,
                    onTap: () => setState(() {
                      _currentIndex = 1;
                      if (_isSelectionMode) {
                        _exitSelectionMode();
                      }
                    }),
                  ),
                  _SidebarItem(
                    icon: Icons.folder_rounded,
                    label: l10n.files,
                    selected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  const Spacer(),
                  // Network mode toggle (Desktop only - Windows/Linux)
                  if (!Platform.isMacOS)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: _NetworkModeTile(
                        settings: widget.settings,
                        onChanged: _restartSystem,
                      ),
                    ),
                  // Bottom actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      children: [
                        _SidebarActionTile(
                          icon: Icons.restart_alt_rounded,
                          label: l10n.restartingSystem,
                          onTap: _restartSystem,
                        ),
                        _SidebarActionTile(
                          icon: Icons.settings_rounded,
                          label: l10n.settings,
                          onTap: _openSettings,
                        ),
                        _SidebarActionTile(
                          icon: Icons.info_outline_rounded,
                          label: l10n.about,
                          onTap: _openAbout,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
          // Main content with max width constraint
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildPage(_currentIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return SendTab(
          devices: _devices,
          isRunning: _isRunning,
          pendingFilePath: _pendingSinanFilePath,
          onPendingFileSent: () => setState(() => _pendingSinanFilePath = null),
        );
      case 1:
        return ReceiveTab(
            localDevice: ApexCore.instance.localDevice, isRunning: _isRunning);
      case 2:
        return FilesTab(
          key: _filesTabKey,
          isSelectionMode: _isSelectionMode,
          selectedFiles: _selectedFiles,
          sortBy: _sortBy,
          sortAscending: _sortAscending,
          onExitSelection: _exitSelectionMode,
          onDeleteSelected: _showDeleteConfirmation,
          onSelectAll: _selectAllFiles,
          onSaveSortPreference: _saveSortPreference,
          onSortByChanged: (v) => setState(() => _sortBy = v),
          onToggleSortOrder: () => setState(() => _sortAscending = !_sortAscending),
          onToggleFileSelection: _toggleFileSelection,
          onOpenFile: _openFile,
          onOpenFileLocation: _openFileLocation,
          onLongPress: _enterSelectionMode,
          getReceivedFiles: _getReceivedFiles,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FloatingSheet(
        scrollable: true,
        child: SettingsScreen(settings: widget.settings, embedded: true),
      ),
    );
  }

  void _openAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FloatingSheet(
        scrollable: true,
        child: AboutScreen(embedded: true),
      ),
    );
  }

  // ─── Files helpers ────────────────────────────────────────────────────────

  Future<void> _openFile(File file) async {
    try {
      await _fileOpsService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        _showErrorSnack('${AppLocalizations.of(context).openFileFailed}: $e');
      }
    }
  }

  Future<void> _openFileLocation(File file) async {
    try {
      await _fileOpsService.openFileLocation(file.path);
    } catch (e) {
      if (mounted) {
        _showErrorSnack('${AppLocalizations.of(context).openLocationFailed}: $e');
      }
    }
  }

  Future<List<FileSystemEntity>> _getReceivedFiles() =>
      FileStorageService().getReceivedFiles();

  void _enterSelectionMode(String path) =>
      setState(() { _isSelectionMode = true; _selectedFiles.add(path); });

  void _exitSelectionMode() =>
      setState(() { _isSelectionMode = false; _selectedFiles.clear(); });

  void _toggleFileSelection(String path) {
    setState(() {
      if (_selectedFiles.contains(path)) {
        _selectedFiles.remove(path);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(path);
      }
    });
  }

  Future<void> _selectAllFiles() async {
    final files = await _getReceivedFiles();
    setState(() => _selectedFiles = files.map((f) => f.path).toSet());
  }

  Future<void> _loadSortPreference() async {
    final prefs = await widget.settings.getPreferences();
    setState(() {
      _sortBy = prefs['sortBy'] ?? 'date';
      _sortAscending = prefs['sortAscending'] ?? false;
    });
  }

  Future<void> _saveSortPreference() async {
    await widget.settings.savePreference('sortBy', _sortBy);
    await widget.settings.savePreference('sortAscending', _sortAscending);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).sortPreferenceSaved),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteFiles),
        content: Text('${l10n.deleteConfirmation} ${_selectedFiles.length} ${l10n.files}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final count = await _fileOpsService.deleteFiles(_selectedFiles, deleteFromFolder: true);
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count ${l10n.filesDeletedCount}'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() { super.dispose(); }
}

// ─── Sidebar widgets (Desktop) ────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: isDark ? 0.2 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, size: 20,
                color: selected ? color
                    : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color
                      : (isDark ? Colors.white70 : Colors.black54),
                )),
          ]),
        ),
      ),
    );
  }
}

class _SidebarActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 18,
                color: isDark ? Colors.white54 : Colors.black45),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black45,
                )),
          ]),
        ),
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─── Floating Nav Bar ─────────────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isRunning;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAboutTap;
  final VoidCallback onRestartTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.isRunning,
    required this.onTap,
    required this.onSettingsTap,
    required this.onAboutTap,
    required this.onRestartTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[900]! : Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.send_rounded,
                    label: l10n.send,
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.download_rounded,
                    label: l10n.receive,
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.folder_rounded,
                    label: l10n.files,
                    selected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  // More menu
                  _MoreButton(
                    isRunning: isRunning,
                    onSettingsTap: onSettingsTap,
                    onAboutTap: onAboutTap,
                    onRestartTap: onRestartTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatefulWidget {
  final bool isRunning;
  final VoidCallback onSettingsTap;
  final VoidCallback onAboutTap;
  final VoidCallback onRestartTap;

  const _MoreButton({
    required this.isRunning,
    required this.onSettingsTap,
    required this.onAboutTap,
    required this.onRestartTap,
  });

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renderBox = context.findRenderObject() as RenderBox;
    final btnPos = renderBox.localToGlobal(Offset.zero);
    final btnSize = renderBox.size;

    _overlay = OverlayEntry(
      builder: (_) => _MenuOverlay(
        anchorPos: btnPos,
        anchorSize: btnSize,
        scaleAnim: _scaleAnim,
        fadeAnim: _fadeAnim,
        isDark: isDark,
        items: [
          _MenuItem(
            icon: Icons.restart_alt_rounded,
            label: l10n.restartingSystem,
            onTap: () { _close(); widget.onRestartTap(); },
          ),
          _MenuItem(
            icon: Icons.settings_rounded,
            label: l10n.settings,
            onTap: () { _close(); widget.onSettingsTap(); },
          ),
          _MenuItem(
            icon: Icons.info_outline_rounded,
            label: l10n.about,
            onTap: () { _close(); widget.onAboutTap(); },
          ),
        ],
        onDismiss: _close,
      ),
    );

    Overlay.of(context).insert(_overlay!);
    _controller.forward(from: 0);
  }

  Future<void> _close() async {
    await _controller.reverse();
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.more_horiz_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            ),
            if (widget.isRunning)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu Overlay ─────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});
}

class _MenuOverlay extends StatelessWidget {
  final Offset anchorPos;
  final Size anchorSize;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final bool isDark;
  final List<_MenuItem> items;
  final VoidCallback onDismiss;

  const _MenuOverlay({
    required this.anchorPos,
    required this.anchorSize,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.isDark,
    required this.items,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // position menu above the button, aligned to its right edge
    const menuWidth = 220.0;
    const itemHeight = 52.0;
    final menuHeight = items.length * itemHeight + 16;
    final left = (anchorPos.dx + anchorSize.width / 2 - menuWidth / 2)
        .clamp(12.0, MediaQuery.of(context).size.width - menuWidth - 12);
    final top = anchorPos.dy - menuHeight - 12;

    return Stack(
      children: [
        // dismiss tap area
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // menu
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: FadeTransition(
            opacity: fadeAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          InkWell(
                            onTap: item.onTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(children: [
                                Icon(item.icon,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : Colors.black87),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.black87,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Network Mode Tile (Desktop only) ───────────────────────────────────────

class _NetworkModeTile extends StatelessWidget {
  final SettingsService settings;
  final VoidCallback onChanged;
  const _NetworkModeTile({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final isWifi = settings.networkMode == NetworkMode.wifi;
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  isWifi ? Icons.wifi_rounded : Icons.cable_rounded,
                  size: 15,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'نوع الشبكة' : 'Network',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ModeBtn(
                      icon: Icons.wifi_rounded,
                      label: isAr ? 'واي فاي' : 'WiFi',
                      selected: isWifi,
                      onTap: () {
                        settings.setNetworkMode(NetworkMode.wifi);
                        onChanged();
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModeBtn(
                      icon: Icons.cable_rounded,
                      label: isAr ? 'شبكة' : 'LAN',
                      selected: !isWifi,
                      onTap: () {
                        settings.setNetworkMode(NetworkMode.ethernet);
                        onChanged();
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.25 : 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? color : (isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? color : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Floating Sheet ───────────────────────────────────────────────────────────

class _FloatingSheet extends StatelessWidget {
  final Widget child;
  final bool scrollable;

  const _FloatingSheet({required this.child, this.scrollable = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheet = Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          scrollable
              ? Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: child,
                ))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: child,
                ),
        ],
      ),
    );

    return scrollable
        ? DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, __) => sheet,
          )
        : SingleChildScrollView(child: sheet);
  }
}
