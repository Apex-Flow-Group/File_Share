import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class DeviceManager {
  /// يجلب اسم الجهاز على الشبكة أو موديله حسب المنصة.
  ///
  /// Desktop → hostname الفعلي (computer name)
  /// Android → model الجهاز (Pixel 8 Pro, Samsung Galaxy S24...)
  ///            لأن `androidInfo.host` هو hostname مكينة البناء وليس له قيمة
  /// iOS     → null (device.name يُغطي نفس المعلومة)
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
        // model هو الاسم التجاري للجهاز (Pixel 8 Pro، Samsung Galaxy S24، إلخ)
        // host هو hostname مكينة البناء — لا قيمة له للمستخدم
        final model = info.model.trim();
        return model.isNotEmpty ? model : null;
      } else if (Platform.isIOS) {
        // device.name يحمل نفس المعلومة (اسم الجهاز المعيَّن من إعدادات iOS)
        return null;
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

  /// يُحدد نوع الجهاز بدقة — TV / tablet / phone / desktop / web
  /// يستخدم Feature Flags الرسمية من Android CDD وiOS SDK
  static Future<String> getDeviceTypePrecise() async {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'desktop';
    }
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        final features = info.systemFeatures;
        // TV: android.software.leanback أو android.hardware.type.television
        if (features.contains('android.software.leanback') ||
            features.contains('android.hardware.type.television')) {
          return 'tv';
        }
        // Tablet: android.hardware.type.tablet (من Android CDD)
        if (features.contains('android.hardware.type.tablet')) {
          return 'tablet';
        }
        return 'phone';
      } catch (_) {
        return 'phone';
      }
    }
    if (Platform.isIOS) {
      try {
        final info = await DeviceInfoPlugin().iosInfo;
        // iPadOS يُعرِّف نفسه بـ 'iPadOS' أو model يبدأ بـ 'iPad'
        if (info.systemName == 'iPadOS' ||
            info.model.toLowerCase().startsWith('ipad')) {
          return 'tablet';
        }
        return 'phone';
      } catch (_) {
        return 'phone';
      }
    }
    return 'unknown';
  }

  static String getDeviceType() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'phone'; // سيُحدَّث بعد initialize عبر getDeviceTypePrecise
    } else if (Platform.isIOS) {
      return 'phone';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'desktop';
    }
    return 'unknown';
  }
}
