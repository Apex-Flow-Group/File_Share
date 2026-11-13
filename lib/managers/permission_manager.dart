import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

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
}
