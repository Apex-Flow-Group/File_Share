import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppLocalizations> show(WidgetTester tester, Device device) async {
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: ConnectionWidget(device: device, onPin: () {}))),
    ));
    await tester.pump();
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('a network device sends files from the chat line only (owner decision)', (tester) async {
    const pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '192.168.8.97', port: 4000);
    final l10n = await show(tester, pc);
    expect(find.text(l10n.sendFile), findsNothing);
    expect(find.bySemanticsLabel(l10n.chatAttach), findsOneWidget);
  });

  testWidgets('a Nearby-only phone has no chat line, so its opened card keeps the send button', (tester) async {
    const phone = Device(id: 'nearby:x', name: 'Ali Phone', type: 'phone', endpointId: 'x');
    final l10n = await show(tester, phone);
    await tester.tap(find.text('Ali Phone'));
    await tester.pumpAndSettle();
    // It sends at once, so it is not named like the chat's "add files".
    expect(find.text(l10n.sendFilesNow), findsOneWidget);
    expect(find.text(l10n.chatPaste), findsNothing, reason: 'no chat over Nearby');
  });
}
