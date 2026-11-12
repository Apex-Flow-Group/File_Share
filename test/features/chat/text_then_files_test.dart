import 'dart:async';

import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/clipboard_monitor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text first, then the files once it arrived (owner decision): sent
/// together, the first message's "accept chat?" held the other device's
/// one question and the files came back "busy", with no way to retry.
const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000);

void main() {
  late Completer<ChatOutcome> answer;
  late List<List<String>> sentFiles;
  late SendOutcome filesOutcome;
  late List<bool> copiedUsed;
  late ChatStore store;

  setUp(() {
    sentFiles = [];
    filesOutcome = SendOutcome.sent;
    copiedUsed = [];
    // The other device asks "accept chat?": the text waits for its user.
    store = ChatStore(send: (t, d, k) async => (outcome: await answer.future, token: null));
  });

  Future<AppLocalizations> show(WidgetTester tester, {List<String> pick = const [], ClipboardItem? copied}) async {
    // Made inside the test, so it completes in the test's own time.
    answer = Completer();
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DeviceChatView(
          store: store,
          device: _pc,
          pickFiles: () async => pick,
          sendFiles: (paths) async {
            sentFiles.add(paths);
            return filesOutcome;
          },
          copied: copied,
          onCopiedUsed: ({required bool sent}) => copiedUsed.add(sent),
        ),
      ),
    ));
    await tester.pump();
    return AppLocalizations.delegate.load(locale);
  }

  Future<void> writeAndSend(WidgetTester tester, AppLocalizations l10n, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pump();
  }

  testWidgets('the files wait while the text waits for "accept chat?"', (tester) async {
    final l10n = await show(tester, pick: ['/tmp/report.pdf']);
    await tester.tap(find.bySemanticsLabel(l10n.chatAttach));
    await tester.pumpAndSettle();
    await writeAndSend(tester, l10n, 'here it is');
    expect(sentFiles, isEmpty, reason: 'no file offer beside the chat question');

    answer.complete(ChatOutcome.sent);
    await tester.pumpAndSettle();
    expect(sentFiles, [
      ['/tmp/report.pdf']
    ]);
  });

  for (final refused in [ChatOutcome.declined, ChatOutcome.noAnswer, ChatOutcome.busy]) {
    testWidgets('text that did not arrive (${refused.name}) keeps its files in the box, unsent',
        (tester) async {
      final l10n = await show(tester, pick: ['/tmp/report.pdf']);
      await tester.tap(find.bySemanticsLabel(l10n.chatAttach));
      await tester.pumpAndSettle();
      await writeAndSend(tester, l10n, 'here it is');
      answer.complete(refused);
      await tester.pumpAndSettle();
      expect(sentFiles, isEmpty);
      expect(find.text('report.pdf'), findsOneWidget, reason: 'back in the box');
    });
  }

  testWidgets('a copied picture that failed to send is kept, so it can be retried', (tester) async {
    filesOutcome = SendOutcome.busy;
    final l10n = await show(tester,
        copied: const ClipboardItem(paths: ['/tmp/apex_clip_1.png'], type: ClipboardItemType.image));
    answer.complete(ChatOutcome.sent);
    await tester.tap(find.text(l10n.chatAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pumpAndSettle();
    expect(sentFiles, [
      ['/tmp/apex_clip_1.png']
    ]);
    expect(copiedUsed, [false], reason: 'not sent: its copy is not deleted');
  });
}
