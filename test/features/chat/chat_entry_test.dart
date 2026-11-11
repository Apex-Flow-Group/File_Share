import 'package:apex_file_share/shared/framed_capsule_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget line, {TextDirection dir = TextDirection.rtl}) =>
      tester.pumpWidget(MaterialApp(
        home: Directionality(textDirection: dir, child: Scaffold(body: Center(child: line))),
      ));

  testWidgets('on a card the whole line is one button to the chat: no typing there',
      (tester) async {
    var opened = 0;
    await show(
        tester,
        FramedCapsuleInput(
          hint: 'اكتب رسالة',
          sendLabel: 'محادثة',
          onSend: (_) => fail('the card never sends by itself'),
          onOpen: () => opened++,
        ));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('اكتب رسالة'));
    // The dim send circle sends nothing; a touch on it still opens the chat.
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    expect(opened, 2);
    expect(find.bySemanticsLabel('محادثة'), findsOneWidget);
  });

  testWidgets('the attach circle sits at the start, send at the end', (tester) async {
    for (final dir in [TextDirection.rtl, TextDirection.ltr]) {
      await show(
          tester,
          SizedBox(
            width: 400,
            child: FramedCapsuleInput(
              hint: 'x',
              sendLabel: 'send',
              onSend: (_) => true,
              onAttach: () {},
              attachLabel: 'attach',
            ),
          ),
          dir: dir);
      final attach = tester.getCenter(find.bySemanticsLabel('attach')).dx;
      final send = tester.getCenter(find.bySemanticsLabel('send')).dx;
      expect(dir == TextDirection.rtl ? attach > send : attach < send, isTrue, reason: '$dir');
    }
  });
}
