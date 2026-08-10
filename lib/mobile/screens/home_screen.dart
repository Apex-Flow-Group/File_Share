import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../screens/about_screen.dart';
import '../../services/settings_service.dart';
import '../../services/update_service.dart';
import '../../shared/apex_bottom_sheet.dart';
import '../../shared/apex_snackbar.dart';
import '../controllers/home_controller.dart';
import '../widgets/home_nav_bar.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/tabs/files_tab.dart';
import '../widgets/tabs/receive_tab.dart';
import '../widgets/tabs/send_tab.dart';
import 'home_dialogs.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  const HomeScreen({required this.settings, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, HomeDialogs {
  late final HomeController _ctrl;
  final _filesTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = HomeController(settings: widget.settings);
    _ctrl.onFileReceived = showFileReceivedSheet;
    _ctrl.onConnectionRequest = showConnectionRequestDialog;
    _ctrl.onError = (msg) => ApexSnackBar.error(context, msg);
    _ctrl.onUpdateAvailable = showUpdateAvailableSheet;
    _ctrl.onUpdateReady = showUpdateReadySheet;
    _ctrl.addListener(_onStateChanged);
    _ctrl.init();
  }

  @override
  void onOpenFilesFromSheet() => _ctrl.setCurrentIndex(2);

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onStateChanged);
    _ctrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UpdateService.instance.onAppResumed();
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600 && width < 900;
    final isDesktop = width >= 900;

    return PopScope(
      canPop: !_ctrl.isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _ctrl.isSelectionMode) {
          _ctrl.exitSelectionMode();
        }
      },
      child: isDesktop
          ? _buildDesktopLayout()
          : isTablet
              ? _buildTabletLayout()
              : _buildMobileLayout(),
    );
  }

  // ─── Mobile layout ──────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Scaffold(
      extendBody: true,
      body: _buildPage(_ctrl.currentIndex),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _ctrl.currentIndex,
        isRunning: _ctrl.isRunning,
        onTap: (i) => _ctrl.setCurrentIndex(i),
        onSettingsTap: _openSettings,
        onAboutTap: _openAbout,
        onRestartTap: _ctrl.refreshDiscovery,
      ),
    );
  }

  // ─── Tablet layout ──────────────────────────────────────────────────────────

  Widget _buildTabletLayout() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
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
              selectedIndex: _ctrl.currentIndex < 3 ? _ctrl.currentIndex : 0,
              onDestinationSelected: (i) => _ctrl.setCurrentIndex(i),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              backgroundColor: Colors.transparent,
              destinations: [
                NavigationRailDestination(
                    icon: const Icon(Icons.send_outlined),
                    selectedIcon: const Icon(Icons.send_rounded),
                    label: Text(l10n.send)),
                NavigationRailDestination(
                    icon: const Icon(Icons.smartphone_outlined),
                    selectedIcon: const Icon(Icons.smartphone_rounded),
                    label: Text(l10n.receive)),
                NavigationRailDestination(
                    icon: const Icon(Icons.folder_outlined),
                    selectedIcon: const Icon(Icons.folder_rounded),
                    label: Text(l10n.files)),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      RailIconButton(
                          icon: Icons.restart_alt_rounded,
                          tooltip: l10n.restartingSystem,
                          onTap: _ctrl.refreshDiscovery),
                      const SizedBox(height: 8),
                      RailIconButton(
                          icon: Icons.settings_rounded,
                          tooltip: l10n.settings,
                          onTap: _openSettings),
                      const SizedBox(height: 8),
                      RailIconButton(
                          icon: Icons.info_outline_rounded,
                          tooltip: l10n.about,
                          onTap: _openAbout),
                      const SizedBox(height: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _ctrl.isRunning ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildPage(_ctrl.currentIndex)),
        ]),
      ),
    );
  }

  // ─── Desktop layout ─────────────────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Row(children: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
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
                            color: isDark ? Colors.white : Colors.black)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _ctrl.isRunning
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color:
                                  _ctrl.isRunning ? Colors.green : Colors.grey,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_ctrl.isRunning ? 'Online' : 'Offline',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ctrl.isRunning
                                  ? Colors.green
                                  : Colors.grey)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SidebarItem(
                    icon: Icons.send_rounded,
                    label: l10n.send,
                    selected: _ctrl.currentIndex == 0,
                    onTap: () => _ctrl.setCurrentIndex(0)),
                SidebarItem(
                    icon: Icons.smartphone_rounded,
                    label: l10n.receive,
                    selected: _ctrl.currentIndex == 1,
                    onTap: () => _ctrl.setCurrentIndex(1)),
                SidebarItem(
                    icon: Icons.folder_rounded,
                    label: l10n.files,
                    selected: _ctrl.currentIndex == 2,
                    onTap: () => _ctrl.setCurrentIndex(2)),
                const Spacer(),
                if (!Platform.isMacOS)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: NetworkModeTile(
                        settings: widget.settings,
                        onChanged: _ctrl.restartSystem),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(children: [
                    SidebarActionTile(
                        icon: Icons.restart_alt_rounded,
                        label: l10n.restartingSystem,
                        onTap: _ctrl.refreshDiscovery),
                    SidebarActionTile(
                        icon: Icons.settings_rounded,
                        label: l10n.settings,
                        onTap: _openSettings),
                    SidebarActionTile(
                        icon: Icons.info_outline_rounded,
                        label: l10n.about,
                        onTap: _openAbout),
                  ]),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _buildPage(_ctrl.currentIndex),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Page builder ───────────────────────────────────────────────────────────

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return SendTab(
          devices: _ctrl.devices,
          pinnedDevices: _ctrl.pinnedDevices,
          isRunning: _ctrl.isRunning,
          isPinned: _ctrl.isPinned,
          onPin: _ctrl.pinDevice,
          onUnpin: _ctrl.unpinDevice,
          pendingFilePath: _ctrl.pendingSinanFilePath,
          onPendingFileSent: _ctrl.clearPendingSinanFile,
          pendingSharedFiles: _ctrl.pendingSharedFiles,
          onSharedFilesSent: _ctrl.clearPendingSharedFiles,
          pendingClipboardItem: _ctrl.pendingClipboardItem,
          onClipboardItemSent: _ctrl.clearPendingClipboardItem,
        );
      case 1:
        return ReceiveTab(
            localDevice: ApexCore.instance.localDevice,
            isRunning: _ctrl.isRunning);
      case 2:
        return FilesTab(
          key: _filesTabKey,
          isSelectionMode: _ctrl.isSelectionMode,
          selectedFiles: _ctrl.selectedFiles,
          sortBy: _ctrl.sortBy,
          sortAscending: _ctrl.sortAscending,
          onExitSelection: _ctrl.exitSelectionMode,
          onDeleteSelected: _ctrl.deleteSelectedFilesWithOption,
          onSelectAll: _ctrl.selectAllFiles,
          onSaveSortPreference: _saveSortPreference,
          onSortByChanged: (v) => _ctrl.setSortBy(v),
          onToggleSortOrder: _ctrl.toggleSortOrder,
          onToggleFileSelection: _ctrl.toggleFileSelection,
          onOpenFile: _openFile,
          onOpenFileLocation: _openFileLocation,
          onLongPress: _ctrl.enterSelectionMode,
          getReceivedFiles: _ctrl.getReceivedFiles,
          refreshNotifier: _ctrl.filesRefreshNotifier,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _openSettings() {
    ApexBottomSheet.show(
      context,
      scrollable: true,
      isScrollControlled: true,
      child: SettingsScreen(
        settings: widget.settings,
        embedded: true,
        onDebugUpdateTap: () {
          Navigator.pop(context);
          showUpdateAvailableSheet();
        },
      ),
    );
  }

  void _openAbout() {
    ApexBottomSheet.show(
      context,
      scrollable: true,
      isScrollControlled: true,
      child: const AboutScreen(embedded: true),
    );
  }

  Future<void> _openFile(File file) async {
    try {
      await _ctrl.fileOpsService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(
            context, '${AppLocalizations.of(context).openFileFailed}: $e');
      }
    }
  }

  Future<void> _openFileLocation(File file) async {
    try {
      await _ctrl.fileOpsService.openFileLocation(file.path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(
            context, '${AppLocalizations.of(context).openLocationFailed}: $e');
      }
    }
  }

  Future<void> _saveSortPreference() async {
    await _ctrl.saveSortPreference();
    if (mounted) {
      ApexSnackBar.info(
          context, AppLocalizations.of(context).sortPreferenceSaved);
    }
  }
}
