import 'dart:io';

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_file_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the TV file tile the way a remote does: arrows, select (OK) and back.
void main() {
  late List<String> calls;

  Widget app(Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: TVFileTile(
                file: File('report.pdf'),
                name: 'report.pdf',
                isDark: false,
                autofocus: true,
                onOpen: () => calls.add('open'),
                onOpenLocation: () => calls.add('folder'),
                onDelete: () => calls.add('delete'),
                onBackToSidebar: () => calls.add('sidebar'),
              ),
            ),
          ),
        ),
      );

  setUp(() => calls = []);

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  bool dialogOpen(WidgetTester tester) => find.byType(Dialog).evaluate().isNotEmpty;

  testWidgets('the tile has focus when the list opens', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    expect(find.byType(TVFileTile), findsOneWidget);
    expect(focused!.context!.findAncestorWidgetOfExactType<TVFileTile>(), isNotNull,
        reason: 'With no focus the remote does nothing on this screen.');
  });

  testWidgets('OK opens the options, the first option is focused', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.select);
    expect(dialogOpen(tester), isTrue);

    await press(tester, LogicalKeyboardKey.select);
    expect(calls, ['open'], reason: 'OK on the first option must open the file.');
    expect(dialogOpen(tester), isFalse);
  });

  testWidgets('the arrows reach every option and OK runs the focused one', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.select);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(calls, ['delete'],
        reason: 'Down, down, OK must reach the third option (delete).');
  });

  testWidgets('the remote Back button closes the options without acting', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.select);
    expect(dialogOpen(tester), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dialogOpen(tester), isFalse);
    expect(calls, isEmpty);
  });

  testWidgets('in Arabic the right arrow goes back to the sidebar', (tester) async {
    await tester.pumpWidget(app(const Locale('ar')));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(calls, ['sidebar']);
  });

  testWidgets('in English the left arrow goes back to the sidebar', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(calls, ['sidebar']);
  });
}
