import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/shared/apex_icons.dart';
import 'package:apex_file_share/shared/apex_theme.dart';
import 'package:apex_file_share/shared/device_card.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_send_device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One card, two states and one movement between them, on the phone, the
/// computer and the TV (owner decision).
const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '192.168.8.97', port: 4000);

void main() {
  setUp(foldDeviceCards);

  Future<AppLocalizations> pump(WidgetTester tester, Widget card,
      {Locale locale = const Locale('ar')}) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      theme: apexTheme(Brightness.light),
      darkTheme: apexTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ));
    await tester.pump();
    return AppLocalizations.delegate.load(locale);
  }

  double grown(WidgetTester tester) => tester
      .widget<SizeTransition>(find.descendant(
          of: find.byType(DeviceCard), matching: find.byType(SizeTransition)))
      .sizeFactor
      .value;

  testWidgets('the phone card and the TV card are the same card', (tester) async {
    await pump(tester, Column(children: [
      const ConnectionWidget(device: _pc),
      TVDeviceCard(device: _pc.copyWith(id: 'q', ip: '192.168.8.98')),
    ]));
    expect(find.byType(DeviceCard), findsNWidgets(2));
  });

  testWidgets('a touch grows it in one movement, and folds it back the same way',
      (tester) async {
    await pump(tester, const ConnectionWidget(device: _pc));
    expect(grown(tester), 0);
    await tester.tap(find.text('Office PC'));
    await tester.pump();
    await tester.pump(Durations.medium2 * 0.5);
    final mid = grown(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    // The content slides with the card: nothing between them fades (the
    // page's own transitions are above the card).
    int fadesAbove(Finder f) =>
        find.ancestor(of: f, matching: find.byType(FadeTransition)).evaluate().length;
    expect(fadesAbove(find.byType(DeviceChatView)), fadesAbove(find.byType(DeviceCard)));
    await tester.pumpAndSettle();
    expect(grown(tester), 1);

    await tester.tap(find.byIcon(ApexIcons.fold));
    await tester.pumpAndSettle();
    expect(grown(tester), 0);
    expect(find.byIcon(ApexIcons.fold), findsNothing);
  });

  testWidgets('opened, the phone and the TV head show the same icons', (tester) async {
    await pump(tester, const ConnectionWidget(device: _pc));
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    expect(find.byIcon(ApexIcons.fold), findsOneWidget);
    expect(find.byIcon(ApexIcons.menu), findsOneWidget);

    foldDeviceCards();
    final node = FocusNode();
    addTearDown(node.dispose);
    await pump(tester, TVDeviceCard(device: _pc, autofocus: true, contentFocusNode: node));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byIcon(ApexIcons.fold), findsOneWidget);
    expect(find.byIcon(ApexIcons.menu), findsOneWidget);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('the remote: OK grows it with the focus on its first send, '
        'back folds it with the focus on the card ($locale)', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final l10n = await pump(
          tester, TVDeviceCard(device: _pc, autofocus: true, contentFocusNode: node),
          locale: locale);
      expect(node.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(grown(tester), 1);
      final first = tester.widget<InkWell>(find.ancestor(
          of: find.text(l10n.sendFilesNow), matching: find.byType(InkWell)));
      expect(first.focusNode?.hasPrimaryFocus, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(grown(tester), 0);
      expect(node.hasPrimaryFocus, isTrue);

      // Down from the opened card reaches its first send too.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(first.focusNode?.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets('a blocked device gets no send on the TV either', (tester) async {
    const blocked = Device(id: 'b', name: 'Stranger', type: 'phone', ip: '192.168.8.66', port: 4000);
    ApexCore.instance.chat.blocked(blocked.chatPeer);
    addTearDown(() => ApexCore.instance.chat.unblock(blocked.chatPeer));
    final l10n = await pump(tester, const TVDeviceCard(device: blocked, autofocus: true),
        locale: const Locale('en'));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatBlocked), findsOneWidget);
    expect(find.text(l10n.sendFilesNow), findsNothing);
    expect(find.text(l10n.sendApp), findsNothing);
    expect(find.text(l10n.sendFolder), findsNothing);
  });

  testWidgets('while another send runs, the phone box offers no send of its own', (tester) async {
    final l10n = await pump(tester, const ConnectionWidget(device: _pc, isGloballyBusy: true));
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatTransferBusy), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.sendFolder), findsNothing);
    expect(find.bySemanticsLabel(l10n.sendApp), findsNothing);
  });

  testWidgets('the TV writes nothing: its chat has no message box', (tester) async {
    await pump(tester, const TVDeviceCard(device: _pc, autofocus: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(ApexIcons.send), findsNothing);
  });
}
