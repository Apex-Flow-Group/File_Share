import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../shared/apex_bottom_sheet.dart';

/// Helper class containing all bottom-sheet dialogs for SettingsScreen.
class SettingsSheets {
  SettingsSheets._();

  // ─── Language Sheet ──────────────────────────────────────────────────────

  static void showLanguageSheet(
      BuildContext context, AppLocalizations l10n, SettingsService settings) {
    final current = settings.locale?.languageCode;
    ApexBottomSheet.showPicker(
      context: context,
      title: l10n.selectLanguage,
      items: [
        PickerItem(
            label: l10n.system, value: null, icon: Icons.phone_android_rounded),
        const PickerItem(
            label: 'العربية', value: 'ar', icon: Icons.translate_rounded),
        const PickerItem(
            label: 'English', value: 'en', icon: Icons.translate_rounded),
      ],
      currentValue: current,
      onSelected: (v) => settings.setLocale(v == null ? null : Locale(v)),
    );
  }

  // ─── Theme Sheet ─────────────────────────────────────────────────────────

  static void showThemeSheet(
      BuildContext context, AppLocalizations l10n, SettingsService settings) {
    final current = settings.themeMode;
    ApexBottomSheet.showPicker(
      context: context,
      title: l10n.selectTheme,
      items: [
        PickerItem(
            label: l10n.system,
            value: 'system',
            icon: Icons.brightness_auto_rounded),
        PickerItem(
            label: l10n.light, value: 'light', icon: Icons.light_mode_rounded),
        PickerItem(
            label: l10n.dark, value: 'dark', icon: Icons.dark_mode_rounded),
      ],
      currentValue: current == ThemeMode.light
          ? 'light'
          : current == ThemeMode.dark
              ? 'dark'
              : 'system',
      onSelected: (v) {
        settings.setThemeMode(v == 'light'
            ? ThemeMode.light
            : v == 'dark'
                ? ThemeMode.dark
                : ThemeMode.system);
      },
    );
  }

  // ─── Permissions Sheet ───────────────────────────────────────────────────

  static void showPermissionsSheet(
      BuildContext context, AppLocalizations l10n) async {
    final perms = <_PermissionItem>[];

    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      perms.addAll([
        if (androidInfo <= 32)
          _PermissionItem(l10n.location, Icons.location_on_rounded,
              const Color(0xFF007AFF), Permission.locationWhenInUse),
        _PermissionItem(l10n.bluetooth, Icons.bluetooth_rounded,
            const Color(0xFF5856D6), Permission.bluetoothScan),
        if (androidInfo >= 33)
          _PermissionItem(l10n.nearbyDevices, Icons.sensors_rounded,
              const Color(0xFF34C759), Permission.nearbyWifiDevices),
        if (androidInfo >= 33)
          _PermissionItem(l10n.storageLabel, Icons.photo_library_rounded,
              const Color(0xFFFF9500), Permission.photos)
        else
          _PermissionItem(l10n.storageLabel, Icons.folder_rounded,
              const Color(0xFFFF9500), Permission.storage),
      ]);
    } else if (Platform.isIOS) {
      perms.addAll([
        _PermissionItem(l10n.location, Icons.location_on_rounded,
            const Color(0xFF007AFF), Permission.location),
        _PermissionItem(l10n.bluetooth, Icons.bluetooth_rounded,
            const Color(0xFF5856D6), Permission.bluetooth),
        _PermissionItem(l10n.storageLabel, Icons.photo_library_rounded,
            const Color(0xFFFF9500), Permission.photos),
      ]);
    }

    final statuses = <_PermissionItem, PermissionStatus>{};
    for (final p in perms) {
      try {
        statuses[p] = await p.permission.status;
      } catch (_) {
        statuses[p] = PermissionStatus.denied;
      }
    }

    if (!context.mounted) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
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
            mainAxisSize: MainAxisSize.min,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(l10n.appPermissions,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    )),
              ),
              ...perms.map((p) {
                final status = statuses[p] ?? PermissionStatus.denied;
                final granted = status.isGranted;
                final restricted = status.isPermanentlyDenied;
                final color = granted
                    ? Colors.green
                    : restricted
                        ? Colors.red
                        : Colors.orange;
                final label = granted
                    ? (isAr ? '✓ ممنوح' : '✓ Granted')
                    : restricted
                        ? (isAr ? '✗ محظور' : '✗ Blocked')
                        : (isAr ? '← اضغط للمنح' : '← Tap to grant');
                return ListTile(
                  onTap: granted
                      ? null
                      : () async {
                          if (restricted) {
                            Navigator.pop(context);
                            await openAppSettings();
                          } else {
                            await p.permission.request();
                            if (context.mounted) {
                              Navigator.pop(context);
                              showPermissionsSheet(context, l10n);
                            }
                          }
                        },
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: p.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(p.icon, size: 18, color: p.color),
                  ),
                  title: Text(p.label),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: Text(l10n.openSettings),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<int> _getAndroidVersion() async {
    try {
      if (!Platform.isAndroid) {
        return 0;
      }
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'API (\d+)').firstMatch(versionStr);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '0') ?? 0;
      }
      return 33;
    } catch (_) {
      return 33;
    }
  }
}

// ─── Data class ────────────────────────────────────────────────────────────────

class _PermissionItem {
  final String label;
  final IconData icon;
  final Color color;
  final Permission permission;
  const _PermissionItem(this.label, this.icon, this.color, this.permission);
}
