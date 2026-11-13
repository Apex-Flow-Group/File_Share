import 'dart:io';

import 'package:apex_file_share/features/receive/data/sender_log.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/tabs/files_tab.dart';
import 'package:apex_file_share/shared/sender_line_text.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_file_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The line under a received file in the files tab: who sent it and when.
void main() {
  /// The name as shown: isolated in its own direction.
  String iso(String name) => '${String.fromCharCode(0x2068)}$name${String.fromCharCode(0x2069)}';
  late Directory root;
  late File received;
  late File other;
  final fingerprint = 'a' * 64;
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 14, 20);

  setUp(() {
    root = Directory.systemTemp.createTempSync('apex_files_tab_sender_');
    // In a category folder, as received files are.
    received = File('${root.path}/Documents/report.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    other = File('${root.path}/Documents/notes.txt')..writeAsStringSync('x');
  });

  tearDown(() => root.deleteSync(recursive: true));

  SenderLog logAt(DateTime at) => SenderLog.memory(clock: () => at)
    ..record(received.path, name: 'هاتف أحمد', fingerprint: fingerprint);

  Widget app(Locale locale, Widget child) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  FilesTab tab(SenderLog senders) => FilesTab(
        isSelectionMode: false,
        selectedFiles: const {},
        sortBy: 'name',
        sortAscending: true,
        onExitSelection: () {},
        onDeleteSelected: () async => 0,
        onSelectAll: () {},
        onSaveSortPreference: () {},
        onSortByChanged: (_) {},
        onToggleSortOrder: () {},
        onToggleFileSelection: (_) {},
        onOpenFile: (_) {},
        onOpenFileLocation: (_) {},
        onLongPress: (_) {},
        getReceivedFiles: () async => [received, other],
        senders: senders,
      );

  testWidgets('a received file shows who sent it and when; a file with no line shows none', (tester) async {
    await tester.pumpWidget(app(const Locale('ar'), tab(logAt(yesterday))));
    await tester.pump();

    expect(find.text('من: ${iso('هاتف أحمد')} · أمس 14:20'), findsOneWidget);
    expect(find.textContaining('من: '), findsOneWidget, reason: 'notes.txt has no sender line');
  });

  testWidgets('a file deleted outside the app shows no line', (tester) async {
    final senders = logAt(yesterday);
    received.deleteSync();
    await tester.pumpWidget(app(const Locale('ar'), tab(senders)));
    await tester.pump();

    expect(find.textContaining('هاتف أحمد'), findsNothing);
  });

  testWidgets('the TV file tile shows the same line', (tester) async {
    final line = logAt(yesterday).of(received.path)!;
    await tester.pumpWidget(app(
        const Locale('en'),
        TVFileTile(
          file: received,
          name: 'report.pdf',
          isDark: false,
          autofocus: false,
          onOpen: () {},
          onOpenLocation: () {},
          onDelete: () {},
          sender: line,
        )));

    expect(find.text('From: ${iso('هاتف أحمد')} · Yesterday 14:20'), findsOneWidget);
  });

  test('a Latin name before an older date keeps its place in an Arabic line', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final line = (name: 'Ali Phone', at: DateTime(2026, 11, 3, 14, 20), fingerprint: fingerprint);
    expect(senderLineText(ar, line, now: DateTime(2026, 11, 12, 12)),
        'من: ${iso('Ali Phone')} · 2026-11-03 14:20');
  });

  test('the day reads today, yesterday, or the date', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final noon = DateTime(2026, 11, 12, 12);
    expect(whenText(ar, DateTime(2026, 11, 12, 9, 5), now: noon), 'اليوم 09:05');
    expect(whenText(ar, DateTime(2026, 11, 11, 14, 20), now: noon), 'أمس 14:20');
    expect(whenText(ar, DateTime(2026, 11, 3, 8, 0), now: noon), '2026-11-03 08:00');
    expect(whenText(ar, DateTime(2026, 10, 31, 23, 59), now: DateTime(2026, 11, 1, 0, 1)), 'أمس 23:59',
        reason: 'yesterday across a month');
  });
}
