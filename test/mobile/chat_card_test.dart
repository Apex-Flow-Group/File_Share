import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '192.168.8.97', port: 4000);
const _tv = Device(id: 't', name: 'Living TV', type: 'tv', ip: '192.168.8.50', port: 4000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;

  setUp(() {
    clipboard = null;
    foldChatCards();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboard == null ? null : {'text': clipboard};
      }
      return null;
    });
  });

  Future<AppLocalizations> show(WidgetTester tester, List<Device> devices) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            for (final d in devices) ConnectionWidget(key: ValueKey(d.id), device: d, onPin: () {}),
          ]),
        ),
      ),
    ));
    await tester.pump();
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('folded: a contact row with paste and send-files, no chat and no send buttons', (tester) async {
    final l10n = await show(tester, [_pc]);
    expect(find.text('Office PC'), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.chatPaste), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.chatAttach), findsOneWidget);
    expect(find.byType(DeviceChatView), findsNothing);
    expect(find.text(l10n.sendFolder), findsNothing);
  });

  testWidgets('folded, it counts new messages and never shows their text', (tester) async {
    ApexCore.instance.chat.receive(_pc.ip, 'Office PC', 'wifi password 8812');
    final l10n = await show(tester, [_pc]);
    expect(find.text(l10n.chatUnread(1)), findsOneWidget);
    expect(find.textContaining('8812'), findsNothing);
  });

  testWidgets('a touch opens it in place: the other sends, then the chat', (tester) async {
    final l10n = await show(tester, [_pc]);
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceChatView), findsOneWidget);
    expect(find.text(l10n.sendFolder), findsOneWidget);
    expect(find.text(l10n.sendFile), findsNothing, reason: 'the clip sends files');
  });

  testWidgets('one card open at a time: opening another folds the first', (tester) async {
    await show(tester, [_pc, _tv]);
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Living TV'));
    await tester.pumpAndSettle();
    final open = tester.widget<DeviceChatView>(find.byType(DeviceChatView));
    expect(find.byType(DeviceChatView), findsOneWidget);
    expect(open.device.id, 't');
  });

  testWidgets('paste opens the card with the copied text in the line, not sent', (tester) async {
    clipboard = 'copied on this phone';
    final l10n = await show(tester, [_pc]);
    await tester.tap(find.bySemanticsLabel(l10n.chatPaste));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'copied on this phone');
    expect(ApexCore.instance.chat.thread(_pc.ip)?.messages.where((m) => m.mine) ?? const [], isEmpty);
  });

  testWidgets('with nothing copied, paste says so and opens nothing', (tester) async {
    final l10n = await show(tester, [_pc]);
    await tester.tap(find.bySemanticsLabel(l10n.chatPaste));
    await tester.pump();
    expect(find.text(l10n.chatClipboardEmpty), findsOneWidget);
    expect(find.byType(DeviceChatView), findsNothing);
  });

  testWidgets('a blocked device: no paste and no send-files on its row', (tester) async {
    const blocked = Device(id: 'b', name: 'Stranger', type: 'phone', ip: '192.168.8.66', port: 4000);
    ApexCore.instance.chat.blocked(blocked.ip);
    final l10n = await show(tester, [blocked]);
    expect(find.bySemanticsLabel(l10n.chatPaste), findsNothing);
    expect(find.bySemanticsLabel(l10n.chatAttach), findsNothing);
  });

  testWidgets('the opened head says it closes the chat, and does', (tester) async {
    final l10n = await show(tester, [_pc]);
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    // The name inside the head is read with it, after the action.
    expect(find.bySemanticsLabel(RegExp('^${l10n.chatClose}')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_less_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceChatView), findsNothing);
  });

  testWidgets('a Nearby-only phone keeps the old card: no chat row', (tester) async {
    const phone = Device(id: 'nearby:x', name: 'Ali Phone', type: 'phone', endpointId: 'x');
    final l10n = await show(tester, [phone]);
    expect(find.bySemanticsLabel(l10n.chatPaste), findsNothing);
    expect(find.text(l10n.sendFilesNow), findsOneWidget);
  });
}
