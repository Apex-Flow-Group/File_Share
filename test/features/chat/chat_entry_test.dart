import 'package:apex_file_share/shared/framed_capsule_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget line, {TextDirection dir = TextDirection.rtl}) =>
      tester.pumpWidget(MaterialApp(
        home: Directionality(textDirection: dir, child: Scaffold(body: Center(child: line))),
      ));

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
