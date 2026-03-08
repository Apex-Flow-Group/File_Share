import 'dart:io';

import 'package:flutter/material.dart';

import '../core/apex_core.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../services/file_operations_service.dart';
import '../services/file_storage_service.dart';
import '../services/settings_service.dart';
import '../widgets/tabs/files_tab.dart';
import '../widgets/tabs/receive_tab.dart';
import '../widgets/tabs/send_tab.dart';
import '../widgets/text_chat_sheet.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  final SettingsService settings;

  const HomeScreen({required this.settings, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Device> _devices = [];
  bool _isRunning = false;
  late TabController _tabController;
  final _fileOpsService = FileOperationsService();

  bool _isSelectionMode = false;
  Set<String> _selectedFiles = {};
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 2 && _isSelectionMode) {
        _exitSelectionMode();
      }
      setState(() {});
    });
    _initializeSystem();
    _loadSortPreference();
  }

  Future<void> _initializeSystem() async {
    ApexCore.instance.devicesStream.listen((devices) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
      });
    });

    ApexCore.instance.fileReceivedStream.listen((event) {
      if (!mounted) {
        return;
      }
      _showFileReceivedDialog(event);
    });

    ApexCore.instance.connectionRequestStream.listen((request) {
      if (!mounted) {
        return;
      }
      _showConnectionRequestDialog(request);
    });

    await _startSystem();
  }

  Future<void> _startSystem() async {
    try {
      await ApexCore.instance.start();
      setState(() {
        _isRunning = true;
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showErrorDialog(l10n.systemStartFailed, e.toString());
      }
    }
  }

  Future<void> _stopSystem() async {
    await ApexCore.instance.stop();
    setState(() {
      _isRunning = false;
      _devices.clear();
    });
  }

  Future<void> _restartSystem() async {
    await _stopSystem();
    await Future.delayed(const Duration(milliseconds: 500));
    await _startSystem();
  }

  void _showFileReceivedDialog(FileReceivedEvent event) {
    final l10n = AppLocalizations.of(context);
    final sizeStr = _formatFileSize(event.fileSize);
    
    // استخراج مسار المجلد من مسار الملف
    final folderPath = event.filePath.substring(0, event.filePath.lastIndexOf('/'));
    final displayPath = folderPath.replaceAll('/storage/emulated/0/', '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, size: 40, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.fileReceived,
                style: const TextStyle(fontSize: 20, color: Colors.green),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.insert_drive_file,
                      size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    event.fileName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sizeStr,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.from}: ${event.fromDevice}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.folder,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.savedIn}: $displayPath',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _tabController.animateTo(2);
              },
              icon: const Icon(Icons.folder_open, size: 22),
              label: Text(
                l10n.openFiles,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionRequestDialog(ConnectionRequest request) {
    final l10n = AppLocalizations.of(context);
    final isChat = request.requestType == 'chat';
    final sizeStr =
        request.fileSize > 0 ? _formatFileSize(request.fileSize) : '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isChat ? Icons.chat : Icons.file_download,
              size: 32,
              color: isChat ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(isChat ? l10n.sendText : l10n.connectionRequest),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.device.name} ${l10n.deviceWantsToConnect}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isChat ? Colors.green : Colors.blue)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isChat ? Icons.message : Icons.insert_drive_file,
                        color: isChat ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isChat ? l10n.typeMessage : request.fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (sizeStr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.fileSize}: $sizeStr',
                      style: TextStyle(
                        color: request.fileSize > 1024 * 1024 * 1024
                            ? Colors.orange
                            : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.acceptConnection),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              request.onResponse(false);
              Navigator.pop(context);
            },
            child: Text(l10n.reject, style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              request.onResponse(true);
              Navigator.pop(context);
              if (isChat) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      TextChatSheet(devices: [request.device]),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isChat ? Colors.green : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.accept),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartSystem();
            },
            child: Text(l10n.reconnectFailed),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    if (isLargeScreen) {
      return _buildLargeScreenLayout(l10n);
    } else {
      return _buildMobileLayout(l10n);
    }
  }

  Widget _buildMobileLayout(AppLocalizations l10n) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
              onPressed: _isRunning ? _stopSystem : _startSystem,
              tooltip: _isRunning ? l10n.stopDiscovery : l10n.startDiscovery,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: _restartSystem,
              tooltip: l10n.restartingSystem,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: const Icon(Icons.send), text: l10n.send),
              Tab(icon: const Icon(Icons.download), text: l10n.receive),
              Tab(icon: const Icon(Icons.folder), text: l10n.files),
            ],
          ),
        ),
        drawer: _buildDrawer(context),
        body: TabBarView(
          controller: _tabController,
          children: _buildTabViews(),
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout(AppLocalizations l10n) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
              onPressed: _isRunning ? _stopSystem : _startSystem,
              tooltip: _isRunning ? l10n.stopDiscovery : l10n.startDiscovery,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: _restartSystem,
              tooltip: l10n.restartingSystem,
            ),
          ],
        ),
        drawer: _buildDrawer(context),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tabController.index,
              onDestinationSelected: (index) {
                _tabController.animateTo(index);
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.send_outlined),
                  selectedIcon: const Icon(Icons.send),
                  label: Text(l10n.send),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.download_outlined),
                  selectedIcon: const Icon(Icons.download),
                  label: Text(l10n.receive),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.folder_outlined),
                  selectedIcon: const Icon(Icons.folder),
                  label: Text(l10n.files),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _buildTabViews(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTabViews() {
    return [
      SendTab(
        devices: _devices,
        isRunning: _isRunning,
      ),
      ReceiveTab(
        localDevice: ApexCore.instance.localDevice,
        isRunning: _isRunning,
      ),
      FilesTab(
        isSelectionMode: _isSelectionMode,
        selectedFiles: _selectedFiles,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        onExitSelection: _exitSelectionMode,
        onDeleteSelected: _showDeleteConfirmation,
        onSelectAll: _selectAllFiles,
        onSaveSortPreference: _saveSortPreference,
        onSortByChanged: (value) => setState(() => _sortBy = value),
        onToggleSortOrder: () =>
            setState(() => _sortAscending = !_sortAscending),
        onToggleFileSelection: _toggleFileSelection,
        onOpenFile: _openFile,
        onOpenFileLocation: _openFileLocation,
        onLongPress: _enterSelectionMode,
        getReceivedFiles: _getReceivedFiles,
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localDevice = ApexCore.instance.localDevice;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.share,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  localDevice?.name ?? l10n.unknownDevice,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.8),
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text(l10n.home),
            selected: _tabController.index == 0,
            onTap: () {
              _tabController.animateTo(0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n.settings),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(settings: widget.settings),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help),
            title: Text(l10n.support),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.about),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(File file) async {
    try {
      await _fileOpsService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.openFileFailed}: $e')),
        );
      }
    }
  }

  Future<void> _openFileLocation(File file) async {
    try {
      await _fileOpsService.openFileLocation(file.path);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.openLocationFailed}: $e')),
        );
      }
    }
  }

  Future<List<FileSystemEntity>> _getReceivedFiles() async {
    return await FileStorageService().getReceivedFiles();
  }

  void _enterSelectionMode(String filePath) {
    setState(() {
      _isSelectionMode = true;
      _selectedFiles.add(filePath);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedFiles.clear();
    });
  }

  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFiles.contains(filePath)) {
        _selectedFiles.remove(filePath);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(filePath);
      }
    });
  }

  Future<void> _selectAllFiles() async {
    final files = await _getReceivedFiles();
    setState(() {
      _selectedFiles = files.map((f) => f.path).toSet();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sortPreferenceSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteFiles),
        content: Text(
            '${l10n.deleteConfirmation} ${_selectedFiles.length} ${l10n.files}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _deleteSelectedFiles();
    }
  }

  Future<void> _deleteSelectedFiles() async {
    final l10n = AppLocalizations.of(context);
    final deletedCount = await _fileOpsService.deleteFiles(
      _selectedFiles,
      deleteFromFolder: true,
    );
    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deletedCount ${l10n.filesDeletedCount}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
