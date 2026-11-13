import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:local_notifier/local_notifier.dart';

import '../features/send/data/send_http.dart' show SendOutcome;
import '../features/send/send_notice.dart';
import '../l10n/generated/app_localizations.dart';

class DesktopNotificationService {
  static final DesktopNotificationService _instance =
      DesktopNotificationService._();
  static DesktopNotificationService get instance => _instance;
  DesktopNotificationService._();

  /// The language the app shows now; the app sets it (main.dart). Until then
  /// it is the app's own default, Arabic.
  Locale locale = const Locale('ar');

  AppLocalizations get _l10n => lookupAppLocalizations(locale);

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
    await localNotifier.setup(appName: 'Apex Transfer');
  }

  Future<void> showFileReceived(String fileName, String fromDevice) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: _l10n.notifFileReceivedTitle,
      body: _l10n.notifFromDevice(fileName, fromDevice),
    );
    await n.show();
  }

  Future<void> showFileSent(String fileName) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: _l10n.notifSentTitle,
      body: fileName,
    );
    await n.show();
  }

  /// The notice that fits how a send ended; none when the user cancelled.
  Future<void> showSendResult(SendOutcome outcome, String label) async {
    switch (sendNoticeFor(outcome)) {
      case SendNotice.sent:
        await showFileSent(label);
      case SendNotice.declined:
        await showSendDeclined(label);
      case SendNotice.failed:
        await showSendFailed(label);
      case null:
        break;
    }
  }

  Future<void> showSendDeclined(String fileName) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: _l10n.sendDeclined,
      body: fileName,
    );
    await n.show();
  }

  Future<void> showSendFailed(String fileName) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: _l10n.notifSendFailedTitle,
      body: fileName,
    );
    await n.show();
  }

  Future<void> showShareUpload(String fileName, String fromDevice) async {
    if (!_isDesktop) {
      return;
    }
    final n = LocalNotification(
      title: _l10n.notifShareUploadTitle,
      body: _l10n.notifFromDevice(fileName, fromDevice),
    );
    await n.show();
  }
}
