import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yesterday's device at this address, and today's, given the same address
/// by the router. Addresses unused by other card tests: the core is shared.
const _first = Device(id: 'laptop-1', name: 'Office PC', type: 'desktop', ip: '192.168.8.120', port: 4000);
const _second = Device(id: 'phone-2', name: 'Guest Phone', type: 'phone', ip: '192.168.8.120', port: 4000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(foldChatCards);

  Future<AppLocalizations> show(WidgetTester tester, Device device) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: ConnectionWidget(key: ValueKey(device.id), device: device, onPin: () {})),
      ),
    ));
    await tester.pump();
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('the new device at the address shows none of the old one\'s chat', (tester) async {
    final chat = ApexCore.instance.chat;
    chat.receive(_first.chatKey, 'Office PC', 'wifi password 8812');
    chat.block(_first.chatKey);

    final l10n = await show(tester, _second);
    expect(find.text(l10n.chatUnread(1)), findsNothing);
    expect(find.bySemanticsLabel(l10n.chatPaste), findsOneWidget, reason: 'the block is not inherited');
    await tester.tap(find.text('Guest Phone'));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceChatView), findsOneWidget);
    expect(find.textContaining('8812'), findsNothing);
    expect(find.text(l10n.chatBlocked), findsNothing);
    expect(find.text(l10n.chatEmpty), findsOneWidget);
  });

  testWidgets('the same device back at its address shows its own chat', (tester) async {
    final chat = ApexCore.instance.chat;
    const back = Device(id: 'laptop-1', name: 'Office PC', type: 'desktop', ip: '192.168.8.121', port: 4000);
    chat.receive(back.chatKey, 'Office PC', 'before sleep');
    final l10n = await show(tester, back.copyWith(port: 4123));
    expect(find.text(l10n.chatUnread(1)), findsOneWidget);
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    expect(find.text('before sleep'), findsOneWidget);
  });
}
