import 'package:apex_file_share/mobile/widgets/home_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// On a tablet the page's header reaches behind the status bar as on the
/// phone (ApexHeader adds the bar's height itself); the rail stays below it.
void main() {
  testWidgets('the page starts at the top and still knows the status bar; the rail is below it',
      (tester) async {
    const bar = 30.0;
    late double pageSeesBar;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1000, 700), padding: EdgeInsets.only(top: bar)),
        child: Scaffold(
          body: TabletBody(
            rail: const SizedBox(key: Key('rail'), width: 80, height: double.infinity),
            page: Builder(builder: (context) {
              pageSeesBar = MediaQuery.paddingOf(context).top;
              return const SizedBox.expand(key: Key('page'));
            }),
          ),
        ),
      ),
    ));

    expect(tester.getTopLeft(find.byKey(const Key('page'))).dy, 0);
    expect(pageSeesBar, bar, reason: 'ApexHeader pads by it');
    expect(tester.getTopLeft(find.byKey(const Key('rail'))).dy, bar);
  });
}
