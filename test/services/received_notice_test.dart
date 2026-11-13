import 'dart:ui' show Locale;

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/services/desktop_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PC notifies once per received batch: one file by its name, more by
/// how many, never the last file's name alone.
void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('one file: its name', () {
    expect(DesktopNotificationService.receivedBody(ar, 'a.pdf', 1, 'PC'),
        ar.notifFromDevice('a.pdf', 'PC'));
  });

  test('ten files: how many, not the last name', () {
    final body = DesktopNotificationService.receivedBody(ar, 'j.pdf', 10, 'PC');
    expect(body, ar.notifFromDevice(ar.clipboardFileCount(10), 'PC'));
    expect(body, isNot(contains('j.pdf')));
  });
}
