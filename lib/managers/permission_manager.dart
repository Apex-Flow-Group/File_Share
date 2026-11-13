import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/generated/app_localizations.dart';

class PermissionManager {
  static Future<bool> requestAll() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final permissions = _requiredPermissions();
    if (permissions.isEmpty) {
      return true;
    }

    final results = await permissions.request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  static List<Permission> _requiredPermissions() {
    // Android 13+ (API 33+)
    return [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
      // location required on Android 12 and below
      Permission.locationWhenInUse,
      // storage
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ];
  }

  static Future<List<String>> checkMissing(BuildContext context) async {
    if (!Platform.isAndroid) {
      return [];
    }

    final l10n = AppLocalizations.of(context);
    final issues = <String>[];

    final checks = {
      Permission.bluetoothAdvertise: l10n.permBluetoothAdvertise,
      Permission.bluetoothConnect: l10n.permBluetoothConnect,
      Permission.bluetoothScan: l10n.permBluetoothScan,
      Permission.nearbyWifiDevices: l10n.permNearbyWifi,
      Permission.locationWhenInUse: l10n.location,
    };

    for (final entry in checks.entries) {
      if (!await entry.key.isGranted) {
        issues.add('• ${entry.value}');
      }
    }

    return issues;
  }
}
