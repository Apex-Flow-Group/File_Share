import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/clipboard_monitor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000);

void main() {
  late ChatStore store;
  late List<List<String>> sentFiles;
  late List<bool> copiedUsed;

  setUp(() {
    store = ChatStore(send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null));
    sentFiles = [];
    copiedUsed = [];
  });

  Future<AppLocalizations> show(WidgetTester tester, {List<String> pick = const [], ClipboardItem? copied}) async {
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
          sendFiles: (paths) async => sentFiles.add(paths),
          copied: copied,
          onCopiedUsed: ({required bool sent}) => copiedUsed.add(sent),
        ),
      ),
    ));
    await tester.pump();
    return AppLocalizations.delegate.load(locale);
  }

  double y(WidgetTester tester, Finder f) => tester.getCenter(f).dy;

  testWidgets('one line until touched, then the text above the buttons', (tester) async {
    final l10n = await show(tester);
    final send = find.bySemanticsLabel(l10n.send);
    expect((y(tester, find.byType(TextField)) - y(tester, send)).abs(), lessThan(4));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(y(tester, send), greaterThan(y(tester, find.byType(TextField)) + 10));
  });

  testWidgets('the clip adds files to the box; send takes the text and the files together',
      (tester) async {
    final l10n = await show(tester, pick: ['/tmp/report.pdf', '/tmp/notes.txt']);
    await tester.tap(find.bySemanticsLabel(l10n.chatAttach));
    await tester.pumpAndSettle();
    expect(find.text('report.pdf'), findsOneWidget, reason: 'a tile in the box');
    expect(sentFiles, isEmpty, reason: 'adding sends nothing');

    await tester.enterText(find.byType(TextField), 'here they are');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pumpAndSettle();
    expect(sentFiles, [
      ['/tmp/report.pdf', '/tmp/notes.txt']
    ]);
    expect(store.thread(_pc.chatKey)!.messages.single.text, 'here they are');
    expect(find.text('report.pdf'), findsNothing, reason: 'the box is empty again');
  });

  testWidgets('files alone can be sent, and a cross takes one out first', (tester) async {
    final l10n = await show(tester, pick: ['/tmp/a.pdf', '/tmp/b.pdf']);
    await tester.tap(find.bySemanticsLabel(l10n.chatAttach));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.chatRemoveFile('a.pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pumpAndSettle();
    expect(sentFiles, [
      ['/tmp/b.pdf']
    ]);
    expect(store.thread(_pc.chatKey)?.messages ?? const [], isEmpty, reason: 'no empty text message');
  });

  testWidgets('a copied picture floats above the box; add puts it in, send sends it', (tester) async {
    const copied = ClipboardItem(paths: ['/tmp/apex_clip_1.png'], type: ClipboardItemType.image);
    final l10n = await show(tester, copied: copied);
    expect(find.text(l10n.chatAdd), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.chatRemoveFile('apex_clip_1.png')), findsNothing,
        reason: 'offered, not in the box yet');

    await tester.tap(find.text(l10n.chatAdd));
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatAdd), findsNothing);
    expect(find.bySemanticsLabel(l10n.chatRemoveFile('apex_clip_1.png')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.send));
    await tester.pumpAndSettle();
    expect(sentFiles, [
      ['/tmp/apex_clip_1.png']
    ]);
    expect(copiedUsed, [true]);
  });

  testWidgets('copied text is offered by its length; add puts it in the box, unsent', (tester) async {
    const copied = ClipboardItem(paths: [], type: ClipboardItemType.text, text: 'secret 8812');
    final l10n = await show(tester, copied: copied);
    expect(find.textContaining('8812'), findsNothing, reason: 'it may be a password');
    await tester.tap(find.text(l10n.chatAdd));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'secret 8812');
    expect(store.thread(_pc.chatKey)?.messages ?? const [], isEmpty);
    expect(copiedUsed, [true]);
  });

  testWidgets('the cross drops the offer, and nothing is sent', (tester) async {
    const copied = ClipboardItem(paths: ['/tmp/apex_clip_2.png'], type: ClipboardItemType.image);
    final l10n = await show(tester, copied: copied);
    await tester.tap(find.byTooltip(l10n.close));
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatAdd), findsNothing);
    expect(copiedUsed, [false]);
    expect(sentFiles, isEmpty);
  });
}
