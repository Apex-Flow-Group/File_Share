import 'package:apex_file_share/shared/apex_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a sheet header fills the top edge to edge, the handle stays a short bar on it', (tester) async {
    const headerKey = Key('header');
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ApexBottomSheet(
          header: SizedBox(key: headerKey, height: 80),
          child: Text('body'),
        ),
      ),
    ));

    final sheet = tester.getRect(find.byType(ApexBottomSheet).first);
    final header = tester.getRect(find.byKey(headerKey));
    // The sheet's own margin is 12 on each side, none on top.
    expect(header.top, sheet.top);
    expect(header.width, sheet.width - 24);

    final handle = find.descendant(
      of: find.byType(Stack),
      matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 36),
    );
    expect(tester.getSize(handle), const Size(36, 4), reason: 'stretched, it became a line across the sheet');
    expect(tester.getCenter(handle).dx, closeTo(header.center.dx, 0.5));
  });
}
