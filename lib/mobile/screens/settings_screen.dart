import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/apex_core.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../utils/platform_detector.dart';
import 'settings_sheets.dart';
import 'tour_screen.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsService settings;
  final bool embedded;
  final VoidCallback? onDebugUpdateTap;

  const SettingsScreen({
    required this.settings,
    this.embedded = false,
    this.onDebugUpdateTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _buildContent(context, l10n);
    if (embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: content,
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, l10n),
        const SizedBox(height: 8),

        // ─── Device ───────────────────────────────────────────────────
        _sectionLabel(context, l10n.device),
        _buildGroup(context, isDark, [
          _SettingsTile(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF007AFF),
            title: l10n.deviceName,
            subtitle: ApexCore.instance.localDevice?.name ?? '—',
            trailing:
                const Icon(Icons.edit_rounded, size: 16, color: Colors.grey),
            onTap: () => SettingsSheets.showRenameDialog(context, l10n),
          ),
        ]),

        // ─── Shared Folder (desktop only) ────────────────────────────
        if (PlatformDetector.instance.isDesktop) ...[
          _sectionLabel(context, l10n.sharedFolder),
          _ShareSettingsSection(settings: settings),
        ],

        // ─── Appearance ───────────────────────────────────────────────
        _sectionLabel(context, l10n.appearance),
        _buildGroup(context, isDark, [
          _SettingsTile(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF007AFF),
            title: l10n.language,
            subtitle: _getLanguageName(settings.locale?.languageCode, context),
            onTap: () =>
                SettingsSheets.showLanguageSheet(context, l10n, settings),
          ),
          _SettingsTile(
            icon: Icons.contrast_rounded,
            iconColor: const Color(0xFF5856D6),
            title: l10n.theme,
            subtitle: _getThemeName(settings.themeMode, context),
            onTap: () => SettingsSheets.showThemeSheet(context, l10n, settings),
          ),
        ]),

        // ─── Permissions ──────────────────────────────────────────────
        if (Platform.isAndroid || Platform.isIOS) ...[
          _sectionLabel(context, l10n.permissions),
          _buildGroup(context, isDark, [
            _SettingsTile(
              icon: Icons.security_rounded,
              iconColor: const Color(0xFF34C759),
              title: l10n.appPermissions,
              subtitle: l10n.managePermissions,
              onTap: () => SettingsSheets.showPermissionsSheet(context, l10n),
            ),
            _SettingsTile(
              icon: Icons.settings_rounded,
              iconColor: const Color(0xFF8E8E93),
              title: l10n.systemSettings,
              subtitle: l10n.openSystemSettings,
              trailing: const Icon(Icons.open_in_new_rounded,
                  size: 16, color: Colors.grey),
              onTap: () => openAppSettings(),
            ),
          ]),
        ],

        // ─── Network ──────────────────────────────────────────────────
        _sectionLabel(context, l10n.network),
        _buildGroup(context, isDark, [
          _SettingsTile(
            icon: Icons.sensors_rounded,
            iconColor: const Color(0xFFFF9500),
            title: l10n.wifiDirect,
            subtitle: l10n.wifiDirectDesc,
          ),
          _SettingsTile(
            icon: Icons.router_rounded,
            iconColor: const Color(0xFF32ADE6),
            title: l10n.localNetwork,
            subtitle: l10n.localNetworkDesc,
          ),
        ]),

        // ─── Debug (debug builds only) ─────────────────────────────────
        if (kDebugMode) ...[
          _sectionLabel(context, '🐞 Debug'),
          _buildGroup(context, isDark, [
            _SettingsTile(
              icon: Icons.slideshow_rounded,
              iconColor: const Color(0xFFFF3B30),
              title: 'Onboarding Screen',
              subtitle: 'Preview the intro tour',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TourScreen(settings: settings),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.system_update_rounded,
              iconColor: const Color(0xFFFF9500),
              title: 'Update Sheet',
              subtitle: 'Preview update available dialog',
              onTap: onDebugUpdateTap,
            ),
          ]),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF8E8E93);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withValues(alpha: 0.15), color.withValues(alpha: 0.03)]
              : [color.withValues(alpha: 0.1), color.withValues(alpha: 0.02)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.settings_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.settings,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // ─── Group ─────────────────────────────────────────────────────────────────

  Widget _buildGroup(
      BuildContext context, bool isDark, List<_SettingsTile> tiles) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: tiles.asMap().entries.map((entry) {
          final i = entry.key;
          final tile = entry.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 0,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              _buildTile(context, tile, i == 0, i == tiles.length - 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, _SettingsTile tile, bool isFirst, bool isLast) {
    final radius = BorderRadius.only(
      topLeft: isFirst ? const Radius.circular(18) : Radius.zero,
      topRight: isFirst ? const Radius.circular(18) : Radius.zero,
      bottomLeft: isLast ? const Radius.circular(18) : Radius.zero,
      bottomRight: isLast ? const Radius.circular(18) : Radius.zero,
    );

    return InkWell(
      onTap: tile.onTap,
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tile.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tile.icon, size: 18, color: tile.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      )),
                  if (tile.subtitle != null)
                    Text(tile.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                ],
              ),
            ),
            tile.trailing ??
                (tile.onTap != null
                    ? Icon(Icons.chevron_right_rounded,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5))
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _getLanguageName(String? code, BuildContext context) {
    if (code == null) {
      return AppLocalizations.of(context).system;
    }
    return code == 'ar' ? 'العربية' : 'English';
  }

  String _getThemeName(ThemeMode mode, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case ThemeMode.light:
        return l10n.light;
      case ThemeMode.dark:
        return l10n.dark;
      default:
        return l10n.system;
    }
  }
}

// ─── Data class ────────────────────────────────────────────────────────────────

class _SettingsTile {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}

// ─── Share Settings Section ────────────────────────────────────────────────

/// قسم إعدادات Shared Folder — StatefulWidget لأنه يعرض toggles تفاعلية.
class _ShareSettingsSection extends StatefulWidget {
  final SettingsService settings;
  const _ShareSettingsSection({required this.settings});

  @override
  State<_ShareSettingsSection> createState() => _ShareSettingsSectionState();
}

class _ShareSettingsSectionState extends State<_ShareSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF5856D6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Enable shared folder
            _ToggleTile(
              icon: Icons.folder_shared_rounded,
              iconColor: color,
              title: l10n.enableSharedFolder,
              subtitle: l10n.enableSharedFolderDesc,
              value: widget.settings.sharedFolderEnabled,
              isDark: isDark,
              onChanged: (v) async {
                await widget.settings.setSharedFolderEnabled(v);
                // إعادة البث الفوري بالحالة الجديدة
                ApexCore.instance.refreshDiscovery();
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            if (widget.settings.sharedFolderEnabled) ...[
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
              ),
              // Allow uploads
              _ToggleTile(
                icon: Icons.upload_rounded,
                iconColor: const Color(0xFF34C759),
                title: l10n.allowShareUploads,
                subtitle: l10n.allowShareUploadsDesc,
                value: widget.settings.allowShareUploads,
                isDark: isDark,
                onChanged: (v) async {
                  await widget.settings.setAllowShareUploads(v);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
