import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/tv/widgets/tv_accept_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The TV no longer accepts by itself: the user answers with the remote.
void main() {
  late List<bool> answers;

  ConnectionRequest request({int count = 1}) => ConnectionRequest(
        device: const Device(id: 'http:192.168.1.20', name: 'Ali Phone', type: 'unknown', ip: '192.168.1.20'),
        fileName: 'photo.jpg',
        fileSize: 2048,
        fileCount: count,
        fileNames: List.generate(count, (i) => 'f$i.jpg'),
        onResponse: answers.add,
      );

  Widget app(Locale locale, ConnectionRequest r) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                autofocus: true,
                onPressed: () => TVAcceptDialog.ask(context, r),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  setUp(() => answers = []);

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Locale locale, [ConnectionRequest? r]) async {
    await tester.pumpWidget(app(locale, r ?? request()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  }

  testWidgets('the dialog shows the sender name and its real address', (tester) async {
    await open(tester, const Locale('en'));
    expect(find.text('Ali Phone'), findsOneWidget);
    expect(find.text('192.168.1.20'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);
  });

  testWidgets('OK right away refuses: the focus starts on Reject', (tester) async {
    await open(tester, const Locale('en'));
    await press(tester, LogicalKeyboardKey.select);
    expect(answers, [false], reason: 'A stray OK must never accept files.');
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('in English, right arrow then OK accepts', (tester) async {
    await open(tester, const Locale('en'));
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    expect(answers, [true]);
  });

  testWidgets('in Arabic, left arrow then OK accepts', (tester) async {
    await open(tester, const Locale('ar'));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.select);
    expect(answers, [true]);
  });

  testWidgets('the remote Back button refuses', (tester) async {
    await open(tester, const Locale('en'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('a batch shows the number of files, not a list to scroll', (tester) async {
    await open(tester, const Locale('en'), request(count: 1000));
    expect(find.textContaining('1000'), findsOneWidget);
    expect(find.text('f999.jpg'), findsNothing);
  });
}
