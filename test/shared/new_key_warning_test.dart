import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/home_dialogs.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/tv/widgets/tv_accept_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision: a known device with a new key is asked about again, and
/// the question says so; accepting with that line is enough, no second step.
/// Widget tests only: testWidgets replaces HttpClient with a fake.
ConnectionRequest _request(List<bool> answers, {required bool keyChanged, RequestKind kind = RequestKind.chat}) =>
    ConnectionRequest(
      device: const Device(id: 'laptop-1', name: 'Office PC', type: 'unknown', ip: '192.168.1.20'),
      fileName: kind == RequestKind.files ? 'report.pdf' : '',
      fileCount: kind == RequestKind.files ? 1 : 0,
      kind: kind,
      keyChanged: keyChanged,
      onResponse: answers.add,
    );

class _PhoneHost extends StatefulWidget {
  const _PhoneHost(this.request);
  final ConnectionRequest request;

  @override
  State<_PhoneHost> createState() => _PhoneHostState();
}

class _PhoneHostState extends State<_PhoneHost> with HomeDialogs {
  @override
  void onOpenFilesFromSheet([String? filePath]) {}

  @override
  bool onOpenChatFromSheet(key) => false;

  @override
  bool hasChatCard(key) => false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => showConnectionRequestDialog(widget.request),
          child: const Text('open'),
        ),
      );
}

class _TvHost extends StatelessWidget {
  const _TvHost(this.request);
  final ConnectionRequest request;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          autofocus: true,
          onPressed: () => TVAcceptDialog.ask(context, request),
          child: const Text('open'),
        ),
      );
}

Future<AppLocalizations> _open(WidgetTester tester, Widget host, Locale locale) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: host,
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(locale);
}

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    group('phone and desktop (${locale.languageCode})', () {
      testWidgets('a new key shows the line, and one tap on accept accepts', (tester) async {
        final answers = <bool>[];
        final l10n = await _open(tester, _PhoneHost(_request(answers, keyChanged: true)), locale);
        expect(find.text(l10n.requestNewKey), findsOneWidget);
        await tester.tap(find.text(l10n.accept));
        await tester.pumpAndSettle();
        expect(answers, [true], reason: 'no second confirmation');
        expect(find.text(l10n.requestNewKey), findsNothing);
      });

      testWidgets('the key it was accepted with shows no line', (tester) async {
        final l10n = await _open(tester, _PhoneHost(_request([], keyChanged: false)), locale);
        expect(find.text(l10n.chatRequestQuestion), findsOneWidget);
        expect(find.text(l10n.requestNewKey), findsNothing);
      });

      testWidgets('a files request with a new key shows the line too', (tester) async {
        final l10n =
            await _open(tester, _PhoneHost(_request([], keyChanged: true, kind: RequestKind.files)), locale);
        expect(find.text(l10n.requestNewKey), findsOneWidget);
      });
    });

    group('TV (${locale.languageCode})', () {
      testWidgets('a new key shows the line, and accepting with the remote accepts', (tester) async {
        final answers = <bool>[];
        final l10n = await _open(tester, _TvHost(_request(answers, keyChanged: true)), locale);
        expect(find.text(l10n.requestNewKey), findsOneWidget);
        // The focus starts on Reject; the other button is Accept.
        await tester.sendKeyEvent(
            locale.languageCode == 'ar' ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(answers, [true], reason: 'no second confirmation');
      });

      testWidgets('the key it was accepted with shows no line', (tester) async {
        final l10n = await _open(tester, _TvHost(_request([], keyChanged: false)), locale);
        expect(find.text(l10n.chatRequestQuestion), findsOneWidget);
        expect(find.text(l10n.requestNewKey), findsNothing);
      });
    });
  }
}
