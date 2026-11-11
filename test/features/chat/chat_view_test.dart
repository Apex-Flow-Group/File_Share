import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000);

void main() {
  late List<String> sent;
  late ChatStore store;
  late ChatOutcome answer;

  setUp(() {
    sent = [];
    answer = ChatOutcome.sent;
    store = ChatStore(send: (text, target, token) async {
      sent.add(text);
      return (outcome: answer, token: null);
    });
  });

  Future<AppLocalizations> show(WidgetTester tester, {required bool canWrite}) async {
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: DeviceChatView(store: store, device: _pc, canWrite: canWrite)),
    ));
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('a received message is shown with a copy button', (tester) async {
    store.receive(_pc.ip, 'Office PC', 'the wifi key');
    final l10n = await show(tester, canWrite: true);
    expect(find.text('the wifi key'), findsOneWidget);
    expect(find.text(l10n.chatCopy), findsOneWidget);
  });

  testWidgets('the TV only shows: no writing line and no copy', (tester) async {
    store.receive(_pc.ip, 'Office PC', 'hello TV');
    final l10n = await show(tester, canWrite: false);
    expect(find.text('hello TV'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(l10n.chatCopy), findsNothing);
  });

  testWidgets('an empty line sends nothing; a written one is sent and cleared', (tester) async {
    final l10n = await show(tester, canWrite: true);
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pump();
    expect(sent, isEmpty);

    await tester.enterText(find.byType(TextField), 'hi there');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pumpAndSettle();
    expect(sent, ['hi there']);
    expect(find.text('hi there'), findsOneWidget, reason: 'in the chat, no longer in the line');
  });

  Future<void> write(WidgetTester tester, AppLocalizations l10n, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pumpAndSettle();
  }

  testWidgets('a message that did not arrive shows why, and resends only when asked', (tester) async {
    answer = ChatOutcome.busy;
    final l10n = await show(tester, canWrite: true);
    await write(tester, l10n, 'hello');
    expect(find.text(l10n.sendReceiverBusy), findsOneWidget);
    expect(sent, hasLength(1));

    answer = ChatOutcome.sent;
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();
    expect(sent, hasLength(2));
    expect(find.text(l10n.sendReceiverBusy), findsNothing);
  });

  for (final outcome in [ChatOutcome.declined, ChatOutcome.updateRequired]) {
    testWidgets('no retry where it would fail the same way again ($outcome)', (tester) async {
      answer = outcome;
      final l10n = await show(tester, canWrite: true);
      await write(tester, l10n, 'hello');
      expect(find.text(l10n.retry), findsNothing);
    });
  }

  testWidgets('a text over the limit stays in the line, whole, and is not sent', (tester) async {
    final l10n = await show(tester, canWrite: true);
    final long = 'a' * (TransferRules.chatTextLimit + 5);
    await write(tester, l10n, long);
    expect(sent, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, long,
        reason: 'nothing cut off unseen');
    expect(find.text(l10n.chatTooLong(TransferRules.chatTextLimit)), findsOneWidget);
  });

  testWidgets('opening the chat marks its messages read', (tester) async {
    store.receive(_pc.ip, 'Office PC', 'a');
    expect(store.unread(_pc.ip), 1);
    await show(tester, canWrite: true);
    expect(store.unread(_pc.ip), 0);
  });
}
