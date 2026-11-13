import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/apex_apps_loader.dart';
import '../../shared/apex_header.dart';
import '../../shared/apex_icons.dart';
import '../../utils/apex_logger.dart';

/// Bottom sheet for selecting apps to send.
/// Supports multi-select and sends all selected apps as a single batch.
class AppsSelectionSheet extends StatefulWidget {
  /// Called with a list of (File, appName) pairs when user confirms selection.
  final Function(List<({File file, String name})>) onAppsSelected;

  const AppsSelectionSheet({required this.onAppsSelected, super.key});

  /// Show as a modal bottom sheet (matching the app's FloatingSheet style).
  static Future<void> show(
    BuildContext context, {
    required Function(List<({File file, String name})>) onAppsSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => AppsSelectionSheet(onAppsSelected: onAppsSelected),
    );
  }

  @override
  State<AppsSelectionSheet> createState() => _AppsSelectionSheetState();
}

class _AppsSelectionSheetState extends State<AppsSelectionSheet> {
  late Future<List<ApexAppInfo>> _appsFuture;
  bool _showSystemApps = false;
  final Set<String> _selectedPackages = {};

  @override
  void initState() {
    super.initState();
    _appsFuture = ApexAppsLoader.getInstalledApps();
  }

  List<ApexAppInfo> _filterApps(List<ApexAppInfo> apps) {
    if (_showSystemApps) {
      return apps;
    }
    return apps.where((a) => !a.isSystemApp).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: Container(
        height: screenHeight * 0.85,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
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
          children: [
            ApexSheetTop(
              header: ApexHeader(
                icon: Icons.android_rounded,
                color: const Color(0xFF34C759),
                title: l10n.installedApps,
                subtitle: _selectedPackages.isNotEmpty
                    ? l10n.selectedCount(_selectedPackages.length)
                    : null,
                trailing: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: l10n.close,
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── System Apps Toggle ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.settings_applications_rounded,
                        size: 18,
                        color: isDark ? Colors.white60 : Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.systemApps,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _showSystemApps,
                      onChanged: (v) => setState(() => _showSystemApps = v),
                      activeTrackColor: color,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Apps List ───────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<ApexAppInfo>>(
                future: _appsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l10n.loadingApps,
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text('${l10n.connectionError}: ${snapshot.error}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(() {
                              _appsFuture = ApexAppsLoader.getInstalledApps();
                            }),
                            child: Text(l10n.reconnectFailed),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.apps, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(l10n.noApps,
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  final allApps = snapshot.data!;
                  final apps = _filterApps(allApps);

                  if (apps.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.appsNoUserApps,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final isSelected =
                          _selectedPackages.contains(app.packageName);

                      String sizeMB;
                      try {
                        final apkFile = File(app.apkPath);
                        sizeMB = (apkFile.lengthSync() / (1024 * 1024))
                            .toStringAsFixed(1);
                      } catch (_) {
                        sizeMB = '?';
                      }

                      return _AppTile(
                        app: app,
                        sizeMB: sizeMB,
                        isSelected: isSelected,
                        isDark: isDark,
                        color: color,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedPackages.remove(app.packageName);
                            } else {
                              _selectedPackages.add(app.packageName);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ─── Send Button ────────────────────────────────────
            if (_selectedPackages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _onSend,
                    icon: const Icon(ApexIcons.send),
                    label: Text(AppLocalizations.of(context)
                        .sendAppsCount(_selectedPackages.length)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF34C759),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onSend() async {
    // Collect selected apps from the future data
    final allApps = await _appsFuture;
    final selected = allApps
        .where((a) => _selectedPackages.contains(a.packageName))
        .map((a) => (file: File(a.apkPath), name: a.name))
        .toList();

    if (selected.isEmpty) {
      return;
    }

    ApexLogger.instance.log('APP_SELECT',
      '📦 تم اختيار ${selected.length} تطبيق للإرسال',
      LogLevel.info,
    );

    if (mounted) {
      Navigator.pop(context);
    }
    widget.onAppsSelected(selected);
  }
}

// ─── App Tile ─────────────────────────────────────────────────────────────────

class _AppTile extends StatelessWidget {
  final ApexAppInfo app;
  final String sizeMB;
  final bool isSelected;
  final bool isDark;
  final Color color;
  final VoidCallback onTap;

  const _AppTile({
    required this.app,
    required this.sizeMB,
    required this.isSelected,
    required this.isDark,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.15 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                app.icon,
                width: 40,
                height: 40,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.android, size: 40, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            // App info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$sizeMB MB',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            // System badge
            if (app.isSystemApp)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SYS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
