import 'dart:io';

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/services/apex_apps_loader.dart';
import 'package:apex_file_share/tv/widgets/tv_apps_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Picking apps to send with the TV remote: a dialog, not a bottom sheet.
void main() {
  // A 1x1 transparent PNG, so the icons decode in the test.
  final icon = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
    8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 0, 1,
    0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);

  ApexAppInfo app(String name, {bool system = false}) => ApexAppInfo(
      name: name, apkPath: '/data/app/$name/base.apk', packageName: 'com.x.$name',
      icon: icon, isSystemApp: system);

  late List<({File file, String name})>? picked;
  late bool closed;

  Widget host(Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                autofocus: true,
                onPressed: () async {
                  picked = await showTVAppsDialog(context,
                      load: () async => [app('Maps'), app('Notes'), app('Settings', system: true)]);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Locale locale) async {
    picked = null;
    closed = false;
    await tester.pumpWidget(host(locale));
    await press(tester, LogicalKeyboardKey.select);
  }

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('the remote picks an app and sends it ($locale)', (tester) async {
      await open(tester, locale);
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Settings'), findsNothing, reason: 'system apps are hidden at first');

      await press(tester, LogicalKeyboardKey.arrowDown); // Maps -> Notes
      await press(tester, LogicalKeyboardKey.select); // select Notes
      await press(tester, LogicalKeyboardKey.arrowDown); // -> send button
      await press(tester, LogicalKeyboardKey.select);

      expect(closed, isTrue);
      expect(picked!.map((a) => a.name), ['Notes']);
      expect(picked!.single.file.path, '/data/app/Notes/base.apk');
    });
  }

  testWidgets('the first app has focus when the dialog opens', (tester) async {
    await open(tester, const Locale('ar'));
    await press(tester, LogicalKeyboardKey.select); // select Maps
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown); // Notes -> send
    await press(tester, LogicalKeyboardKey.select);
    expect(picked!.map((a) => a.name), ['Maps']);
  });

  testWidgets('system apps appear once the remote turns them on', (tester) async {
    await open(tester, const Locale('en'));
    await press(tester, LogicalKeyboardKey.arrowUp); // first app -> system apps switch
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Back closes the dialog and sends nothing', (tester) async {
    await open(tester, const Locale('ar'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked, isNull);
  });

  testWidgets('send does nothing while no app is chosen', (tester) async {
    await open(tester, const Locale('en'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown); // -> send button
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.pickApp), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    expect(closed, isFalse);
  });
}
