import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsService settings;

  const SettingsScreen({required this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
          _buildSection(context, l10n.appearance),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.language, size: 20),
            title: Text(l10n.language, style: const TextStyle(fontSize: 14)),
            subtitle: Text(_getLanguageName(settings.locale?.languageCode, context), style: const TextStyle(fontSize: 12)),
            onTap: () => _showLanguageDialog(context),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.brightness_6, size: 20),
            title: Text(l10n.theme, style: const TextStyle(fontSize: 14)),
            subtitle: Text(_getThemeName(settings.themeMode, context), style: const TextStyle(fontSize: 12)),
            onTap: () => _showThemeDialog(context),
          ),
          const Divider(),
          if (Platform.isAndroid || Platform.isIOS)
            _buildSection(context, l10n.permissions),
          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.security, size: 20),
              title: Text(l10n.appPermissions, style: const TextStyle(fontSize: 14)),
              subtitle: Text(l10n.managePermissions, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _showPermissionsDialog(context),
            ),
          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.settings, size: 20),
              title: Text(l10n.systemSettings, style: const TextStyle(fontSize: 14)),
              subtitle: Text(l10n.openSystemSettings, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.open_in_new, size: 14),
              onTap: () => openAppSettings(),
            ),
          const Divider(),
          _buildSection(context, l10n.network),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.wifi, size: 20),
            title: Text(l10n.wifiDirect, style: const TextStyle(fontSize: 14)),
            subtitle: Text(l10n.wifiDirectDesc, style: const TextStyle(fontSize: 12)),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.router, size: 20),
            title: Text(l10n.localNetwork, style: const TextStyle(fontSize: 14)),
            subtitle: Text(l10n.localNetworkDesc, style: const TextStyle(fontSize: 12)),
          ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLang = settings.locale?.languageCode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.system),
              leading: Icon(
                currentLang == null ? Icons.check_circle : Icons.circle_outlined,
                color: currentLang == null ? Theme.of(context).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setLocale(null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('العربية'),
              leading: Icon(
                currentLang == 'ar' ? Icons.check_circle : Icons.circle_outlined,
                color: currentLang == 'ar' ? Theme.of(context).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setLocale(const Locale('ar'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              leading: Icon(
                currentLang == 'en' ? Icons.check_circle : Icons.circle_outlined,
                color: currentLang == 'en' ? Theme.of(context).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentTheme = settings.themeMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectTheme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.light),
              leading: Icon(
                currentTheme == ThemeMode.light ? Icons.check_circle : Icons.circle_outlined,
                color: currentTheme == ThemeMode.light ? Theme.of(context).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.dark),
              leading: Icon(
                currentTheme == ThemeMode.dark ? Icons.check_circle : Icons.circle_outlined,
                color: currentTheme == ThemeMode.dark ? Theme.of(context).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.system),
              leading: Icon(
                currentTheme == ThemeMode.system ? Icons.check_circle : Icons.circle_outlined,
                color: currentTheme == ThemeMode.system ? Theme.of(context).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showPermissionsDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    
    // تحديد الصلاحيات حسب المنصة
    final permissions = <String, Permission>{};
    
    if (Platform.isAndroid) {
      permissions['location'] = Permission.location;
      permissions['bluetooth'] = Permission.bluetoothScan;
      permissions['storage'] = Permission.storage;
      permissions['nearbyDevices'] = Permission.nearbyWifiDevices;
    } else if (Platform.isIOS) {
      permissions['location'] = Permission.location;
      permissions['bluetooth'] = Permission.bluetooth;
      permissions['storage'] = Permission.photos;
    }

    final statuses = <String, PermissionStatus>{};
    for (var entry in permissions.entries) {
      try {
        statuses[entry.key] = await entry.value.status;
      } catch (e) {
        statuses[entry.key] = PermissionStatus.denied;
      }
    }

    if (!context.mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appPermissions),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statuses.containsKey('location'))
                _buildPermissionTile(
                  context,
                  Icons.location_on,
                  l10n.location,
                  statuses['location']!,
                ),
              if (statuses.containsKey('bluetooth'))
                _buildPermissionTile(
                  context,
                  Icons.bluetooth,
                  l10n.bluetooth,
                  statuses['bluetooth']!,
                ),
              if (statuses.containsKey('storage'))
                _buildPermissionTile(
                  context,
                  Icons.folder,
                  l10n.storageLabel,
                  statuses['storage']!,
                ),
              if (statuses.containsKey('nearbyDevices'))
                _buildPermissionTile(
                  context,
                  Icons.wifi,
                  l10n.nearbyDevices,
                  statuses['nearbyDevices']!,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(BuildContext context, IconData icon, String title,
      PermissionStatus status) {
    final isGranted = status.isGranted;
    return ListTile(
      leading: Icon(icon, color: isGranted ? Colors.green : Colors.orange),
      title: Text(title),
      trailing: Icon(
        isGranted ? Icons.check_circle : Icons.warning,
        color: isGranted ? Colors.green : Colors.orange,
      ),
    );
  }

  String _getLanguageName(String? code, BuildContext context) {
    if (code == null) {
      return AppLocalizations.of(context).system;
    }
    return code == 'ar' ? 'العربية' : 'English';
  }

  String _getThemeName(ThemeMode mode, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (mode == ThemeMode.light) {
      return l10n.light;
    }
    if (mode == ThemeMode.dark) {
      return l10n.dark;
    }
    return l10n.system;
  }
}
