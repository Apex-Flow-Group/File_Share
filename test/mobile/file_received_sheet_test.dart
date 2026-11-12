import 'dart:async';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/home_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A second file arriving replaces the "file received" sheet. It used to
/// close whatever was on top: with Settings opened over the first sheet,
/// Settings closed and the old sheet stayed.
FileReceivedEvent _file(String name) => FileReceivedEvent(
      fileName: name,
      fileSize: 5,
      fromDevice: 'Phone',
      filePath: '/tmp/$name',
    );

late _HostState _host;

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with HomeDialogs {
  @override
  void onOpenFilesFromSheet([String? filePath]) {}

  @override
  bool onOpenChatFromSheet(key) => false;

  @override
  bool hasChatCard(key) => false;

  @override
  Widget build(BuildContext context) {
    _host = this;
    return const Scaffold(body: SizedBox.expand());
  }
}

void main() {
  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Host(),
    ));
  }

  testWidgets('a second file replaces the sheet and leaves Settings open', (tester) async {
    await start(tester);
    _host.showFileReceivedSheet(_file('first.txt'));
    await tester.pumpAndSettle();
    expect(find.text('first.txt'), findsOneWidget);

    unawaited(showModalBottomSheet<void>(
        context: _host.context, builder: (_) => const SizedBox(height: 200, child: Text('SETTINGS'))));
    await tester.pumpAndSettle();

    _host.showFileReceivedSheet(_file('second.txt'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget, reason: 'Settings was not what arrived');
    expect(find.text('first.txt'), findsNothing, reason: 'the old sheet is replaced');
    expect(find.text('second.txt'), findsOneWidget);
  });

  testWidgets('with nothing over it, a second file still replaces the sheet', (tester) async {
    await start(tester);
    _host.showFileReceivedSheet(_file('first.txt'));
    await tester.pumpAndSettle();
    _host.showFileReceivedSheet(_file('second.txt'));
    await tester.pumpAndSettle();
    expect(find.text('first.txt'), findsNothing);
    expect(find.text('second.txt'), findsOneWidget);
  });

  testWidgets('after the sheet is closed, a new file does not close anything else',
      (tester) async {
    await start(tester);
    _host.showFileReceivedSheet(_file('first.txt'));
    await tester.pumpAndSettle();
    Navigator.of(_host.context).pop();
    await tester.pumpAndSettle();

    unawaited(showModalBottomSheet<void>(
        context: _host.context, builder: (_) => const SizedBox(height: 200, child: Text('SETTINGS'))));
    await tester.pumpAndSettle();
    _host.showFileReceivedSheet(_file('second.txt'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('second.txt'), findsOneWidget);
  });
}
