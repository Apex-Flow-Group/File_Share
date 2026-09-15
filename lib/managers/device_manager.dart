import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class DeviceManager {
  /// يجلب hostname الجهاز على الشبكة (computer name / model name)
  static Future<String?> getHostname() async {
    try {
      if (kIsWeb) {
        return null;
      }
      if (Platform.isWindows) {
        final info = await DeviceInfoPlugin().windowsInfo;
        return info.computerName;
      } else if (Platform.isLinux) {
        final info = await DeviceInfoPlugin().linuxInfo;
        return info.prettyName.isNotEmpty
            ? info.prettyName
            : Platform.localHostname;
      } else if (Platform.isMacOS) {
        final info = await DeviceInfoPlugin().macOsInfo;
        return info.hostName.isNotEmpty ? info.hostName : info.computerName;
      } else if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        // host هو hostname الجهاز على الشبكة، model هو اسم الموديل
        final host = info.host;
        return host.isNotEmpty ? host : info.model;
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return info.name;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> getDeviceName(String fallback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('device_display_name');
      if (savedName != null && savedName.isNotEmpty) {
        return savedName;
      }

      final deviceInfo = DeviceInfoPlugin();
      String deviceName;

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceName = '${webInfo.browserName} Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceName = linuxInfo.prettyName.isNotEmpty
            ? linuxInfo.prettyName.split(' ').first
            : fallback;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceName = windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceName = macInfo.computerName;
      } else {
        deviceName = fallback;
      }

      await prefs.setString('device_display_name', deviceName);
      return deviceName;
    } catch (e) {
      return fallback;
    }
  }

  static String getDeviceType() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return _isAndroidTV() ? 'tv' : 'phone';
    } else if (Platform.isIOS) {
      return 'phone';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'desktop';
    }
    return 'unknown';
  }

  static bool _isAndroidTV() {
    try {
      // سيتم التحقق من TV في runtime
      return false;
    } catch (e) {
      return false;
    }
  }
}
