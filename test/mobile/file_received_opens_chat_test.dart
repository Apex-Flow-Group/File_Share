import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/home_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Owner decision: the received sheet opens the sender's chat, where the
// file's line opens the file and its folder, not the files tab.
final _fp = 'a' * 64;

FileReceivedEvent _overNetwork(String name, {int total = 1}) => FileReceivedEvent(
      fileName: name,
      fileSize: 5,
      fromDevice: 'Office PC',
      filePath: '/tmp/$name',
      fromAddress: '192.168.8.97',
      fromId: 'pc',
      fromFingerprint: _fp,
      batchId: 7,
      batchTotal: total,
      batchIndex: total,
    );

late _HostState _host;

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with HomeDialogs {
  final chats = <ChatKey>[];
  final folders = <String?>[];

  /// Whether the sender's card is on the send tab.
  bool listed = true;

  @override
  void onOpenFilesFromSheet([String? filePath]) => folders.add(filePath);

  @override
  bool hasChatCard(ChatKey key) => listed;

  @override
  bool onOpenChatFromSheet(ChatKey key) {
    if (!listed) {
      return false;
    }
    chats.add(key);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _host = this;
    return const Scaffold(body: SizedBox.expand());
  }
}

void main() {
  Future<AppLocalizations> start(WidgetTester tester) async {
    const locale = Locale('ar');
    await tester.pumpWidget(const MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Host(),
    ));
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('a file from a network device: the sheet opens its chat', (tester) async {
    final l10n = await start(tester);
    final event = _overNetwork('report.pdf');
    ApexCore.instance.chat.receivedFile(event);
    _host.showFileReceivedSheet(event);
    await tester.pumpAndSettle();
    expect(find.text(l10n.openFolder), findsNothing);
    await tester.tap(find.text(l10n.chatOpen));
    await tester.pumpAndSettle();
    expect(_host.chats, [ChatKey(_fp)]);
    expect(_host.folders, isEmpty);
  });

  testWidgets('a batch opens the chat too, not the files tab', (tester) async {
    final l10n = await start(tester);
    final event = _overNetwork('b.pdf', total: 2);
    ApexCore.instance.chat.receivedFile(event);
    _host.showFileReceivedSheet(event);
    await tester.pumpAndSettle();
    expect(find.text(l10n.openFiles), findsNothing);
    await tester.tap(find.text(l10n.chatOpen));
    await tester.pumpAndSettle();
    expect(_host.chats, [ChatKey(_fp)]);
  });

  // Arabic review: the chat opens in its device's card, so with the device
  // gone from the list the button showed an empty send tab.
  testWidgets('its device gone from the list: the sheet opens the folder', (tester) async {
    final l10n = await start(tester);
    final event = _overNetwork('late.pdf');
    ApexCore.instance.chat.receivedFile(event);
    _host.listed = false;
    _host.showFileReceivedSheet(event);
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatOpen), findsNothing);
    await tester.tap(find.text(l10n.openFolder));
    await tester.pumpAndSettle();
    expect(_host.folders, ['/tmp/late.pdf']);
    expect(_host.chats, isEmpty);
  });

  testWidgets('over Nearby there is no chat: the sheet still opens the folder', (tester) async {
    final l10n = await start(tester);
    _host.showFileReceivedSheet(
        FileReceivedEvent(fileName: 'n.jpg', fileSize: 5, fromDevice: 'Ali Phone', filePath: '/tmp/n.jpg'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.chatOpen), findsNothing);
    await tester.tap(find.text(l10n.openFolder));
    await tester.pumpAndSettle();
    expect(_host.folders, ['/tmp/n.jpg']);
  });
}
