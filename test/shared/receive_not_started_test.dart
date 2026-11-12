import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/tabs/receive_tab.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_receive_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Before the system runs, the receive tab says it is starting; only after
/// a failed start does it say so and offer a retry (owner decision).
void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  final tabs = <String, Widget Function(bool failed, VoidCallback onRetry)>{
    'phone': (failed, onRetry) => ReceiveTab(
        localDevice: null, isRunning: false, startFailed: failed, onRetry: onRetry),
    'TV': (failed, onRetry) => TVReceiveTab(
        localDevice: null, isRunning: false, startFailed: failed, onRetry: onRetry),
  };

  for (final MapEntry(key: name, value: tab) in tabs.entries) {
    testWidgets('$name: a start still running is not a failure', (tester) async {
      await tester.pumpWidget(app(tab(false, () {})));
      await tester.pump();
      expect(find.text(ar.starting), findsOneWidget);
      expect(find.text(ar.startFailed), findsNothing);
      expect(find.text(ar.retry), findsNothing);
    });

    testWidgets('$name: a failed start offers a retry that starts again', (tester) async {
      var retries = 0;
      await tester.pumpWidget(app(tab(true, () => retries++)));
      await tester.pump();
      expect(find.text(ar.startFailed), findsOneWidget);
      expect(find.text(ar.starting), findsNothing);
      await tester.tap(find.text(ar.retry));
      await tester.pump();
      expect(retries, 1);
    });
  }
}
