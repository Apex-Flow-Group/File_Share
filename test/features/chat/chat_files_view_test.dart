import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000);

FileReceivedEvent _got(String name, int index, int total) => FileReceivedEvent(
      fileName: name,
      fileSize: 1024,
      fromDevice: 'PC',
      fromAddress: _pc.ip,
      batchId: 1,
      filePath: '/save/$name',
      batchIndex: index,
      batchTotal: total,
      isLastInBatch: index == total,
    );

void main() {
  late ChatStore store;
  setUp(() => store = ChatStore(
        send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null),
        sendFilesNow: (files, target, onDelivered) async => SendOutcome.declined,
      ));

  Future<AppLocalizations> show(WidgetTester tester,
      {required bool canWrite, Future<List<String>> Function()? pickFiles}) async {
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: DeviceChatView(store: store, device: _pc, canWrite: canWrite, pickFiles: pickFiles)),
    ));
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('one received file: its name, open it, or open its folder', (tester) async {
    store.receivedFile(_got('report.pdf', 1, 1));
    final l10n = await show(tester, canWrite: true);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text(l10n.openFile), findsOneWidget);
    expect(find.text(l10n.openFolder), findsOneWidget);
    expect(find.text(l10n.chatCopy), findsNothing, reason: 'a file line has no copy');
  });

  testWidgets('a batch shows the first names and how many more, and its folder', (tester) async {
    for (var i = 1; i <= 5; i++) {
      store.receivedFile(_got('f$i.jpg', i, 5));
    }
    final l10n = await show(tester, canWrite: true);
    expect(find.text('f1.jpg'), findsOneWidget);
    expect(find.text('f3.jpg'), findsOneWidget);
    expect(find.text('f4.jpg'), findsNothing);
    expect(find.text(l10n.chatMoreFiles(2)), findsOneWidget);
    expect(find.text(l10n.openFile), findsNothing, reason: 'which of five would it open?');
    expect(find.text(l10n.openFolder), findsOneWidget);
  });

  testWidgets('the TV opens a file but has no folder button', (tester) async {
    store.receivedFile(_got('report.pdf', 1, 1));
    final l10n = await show(tester, canWrite: false);
    expect(find.text(l10n.openFile), findsOneWidget);
    expect(find.text(l10n.openFolder), findsNothing);
  });

  testWidgets('a refused send of mine says why, with no retry', (tester) async {
    await store.sendFiles(_pc, const [ChatFile('a.pdf', 10, '/tmp/a.pdf')]);
    final l10n = await show(tester, canWrite: true);
    expect(find.text(l10n.sendDeclined), findsOneWidget);
    expect(find.text(l10n.retry), findsNothing);
  });

  testWidgets('the TV shows why a send of its own failed, with no retry', (tester) async {
    store = ChatStore(
      send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null),
      sendFilesNow: (files, target, onDelivered) async => SendOutcome.busy,
    );
    await store.sendFiles(_pc, const [ChatFile('a.pdf', 10, 'test/features/chat/chat_files_view_test.dart')]);
    final l10n = await show(tester, canWrite: true);
    expect(find.text(l10n.retry), findsOneWidget, reason: 'the phone can retry: the file exists');
    await show(tester, canWrite: false);
    expect(find.text(l10n.retry), findsNothing);
  });

  testWidgets('the attach circle is there only where files can be sent', (tester) async {
    var attached = 0;
    final l10n = await show(tester, canWrite: true, pickFiles: () async {
      attached++;
      return const <String>[];
    });
    await tester.tap(find.bySemanticsLabel(l10n.chatAttach));
    expect(attached, 1);

    await show(tester, canWrite: true);
    expect(find.bySemanticsLabel(l10n.chatAttach), findsNothing);
  });
}
