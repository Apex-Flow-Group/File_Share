import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/tabs/send_tab.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_send_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// With no device to show, the send tab says the start state: a search that
/// never began is not "no devices", and a failed start offers a retry
/// (owner decision).
void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  final tabs = <String, Widget Function(bool failed, VoidCallback onRetry)>{
    'phone': (failed, onRetry) => SendTab(
        devices: const [],
        pinnedDevices: const [],
        isRunning: false,
        startFailed: failed,
        onRetry: onRetry,
        isPinned: (_) => false,
        onPin: (_) async {},
        onUnpin: (_) async {}),
    'TV': (failed, onRetry) => TVSendTab(
        devices: const [],
        pinnedDevices: const [],
        isRunning: false,
        startFailed: failed,
        onRetry: onRetry,
        isPinned: (_) => false,
        onPin: (_) async {},
        onUnpin: (_) async {}),
  };

  for (final MapEntry(key: name, value: tab) in tabs.entries) {
    testWidgets('$name: while starting it says so, not that none were found', (tester) async {
      await tester.pumpWidget(app(tab(false, () {})));
      await tester.pump();
      expect(find.text(ar.starting), findsOneWidget);
      expect(find.text(ar.makeSureDevicesOnSameNetwork), findsNothing);
      expect(find.text(ar.retry), findsNothing);
    });

    testWidgets('$name: a failed start says it and offers a retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(app(tab(true, () => retries++)));
      await tester.pump();
      expect(find.text(ar.startFailed), findsOneWidget);
      expect(find.text(ar.makeSureDevicesOnSameNetwork), findsNothing);
      await tester.tap(find.text(ar.retry));
      await tester.pump();
      expect(retries, 1);
    });
  }
}
