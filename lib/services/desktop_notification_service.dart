import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

class DesktopNotificationService {
  static final DesktopNotificationService _instance =
      DesktopNotificationService._();
  static DesktopNotificationService get instance => _instance;
  DesktopNotificationService._();

  static bool get _isDesktop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<void> initialize() async {
    if (!_isDesktop) {
      return;
    }
    await localNotifier.setup(appName: 'Apex File Share');
  }

  Future<void> showFileReceived(String fileName, String fromDevice) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: 'تم استلام ملف ✅',
      body: '$fileName — من $fromDevice',
    );
    await n.show();
  }

  Future<void> showFileSent(String fileName) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: 'تم الإرسال ✅',
      body: fileName,
    );
    await n.show();
  }

  Future<void> showSendFailed(String fileName) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: 'فشل الإرسال ❌',
      body: fileName,
    );
    await n.show();
  }
}
