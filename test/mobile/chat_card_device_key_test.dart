import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/shared/device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chat belongs to the device's certificate (owner decision). Addresses
/// and ids unused by other card tests: the core is shared, and a block holds
/// the id too.
/// Yesterday's device at this address, and today's, given the same address
/// by the router, each with its own certificate.
final _first = Device(
    id: 'laptop-1', name: 'Office PC', type: 'desktop', ip: '192.168.8.120', port: 4000, fingerprint: '1' * 64);
final _second = Device(
    id: 'phone-2', name: 'Guest Phone', type: 'phone', ip: '192.168.8.120', port: 4000, fingerprint: '2' * 64);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(foldDeviceCards);

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
    chat.receive(_first.chatPeer, 'Office PC', 'wifi password 8812');
    chat.block(_first.chatPeer);

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

  testWidgets('the same device back at a new address shows its own chat', (tester) async {
    final chat = ApexCore.instance.chat;
    final before = Device(
        id: 'laptop-3', name: 'Office PC', type: 'desktop', ip: '192.168.8.121', port: 4000, fingerprint: '3' * 64);
    chat.receive(before.chatPeer, 'Office PC', 'before sleep');
    final l10n = await show(tester, before.copyWith(ip: '192.168.8.122', port: 4123));
    expect(find.text(l10n.chatUnread(1)), findsOneWidget);
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    expect(find.text('before sleep'), findsOneWidget);
  });

  testWidgets("a device announcing a colleague's id with its own key shows none of its chat", (tester) async {
    final chat = ApexCore.instance.chat;
    final colleague = Device(
        id: 'desk-4', name: 'Accounts PC', type: 'desktop', ip: '192.168.8.130', port: 4000, fingerprint: '4' * 64);
    chat.receive(colleague.chatPeer, 'Accounts PC', 'salary 9100');
    final impostor = colleague.copyWith(fingerprint: '5' * 64);
    final l10n = await show(tester, impostor);
    expect(find.text(l10n.chatUnread(1)), findsNothing);
    await tester.tap(find.text('Accounts PC'));
    await tester.pumpAndSettle();
    expect(find.textContaining('9100'), findsNothing);
    expect(find.text(l10n.chatEmpty), findsOneWidget);
  });
}
