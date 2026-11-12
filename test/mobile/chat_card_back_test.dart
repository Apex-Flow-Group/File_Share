import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Owner decision: back goes one step at a time. The system closes the
// keyboard itself; then back leaves the box, then folds the card.
const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '192.168.8.97', port: 4000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(foldChatCards);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: ConnectionWidget(device: _pc, onPin: () {})),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
  }

  bool writing(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

  testWidgets('back first leaves the box and keeps the card open', (tester) async {
    await open(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(writing(tester), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(writing(tester), isFalse);
    expect(find.byType(DeviceChatView), findsOneWidget);
  });

  testWidgets('back out of the box folds the card', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DeviceChatView), findsNothing);
    expect(find.text('Office PC'), findsOneWidget, reason: 'the folded row is still there');
  });
}
