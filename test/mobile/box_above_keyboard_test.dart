import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/shared/device_card.dart';
import 'package:apex_file_share/shared/framed_capsule_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// While writing, the whole message box sits above the keyboard, and stays
/// there as messages arrive (owner decision): the list moves, the card does
/// not change.
const _keyboard = 600.0;
const _height = 1200.0;

void main() {
  setUp(foldDeviceCards);

  Future<void> show(WidgetTester tester, Device open) async {
    tester.view.physicalSize = const Size(500, _height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            for (var i = 0; i < 3; i++)
              ConnectionWidget(
                  key: ValueKey(i),
                  device: Device(id: 'd$i', name: 'Device $i', type: 'desktop', ip: '10.0.0.$i', port: 4000)),
            ConnectionWidget(key: const ValueKey('open'), device: open),
            const SizedBox(height: 120),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text(open.name));
    await tester.pumpAndSettle();
  }

  double boxBottom(WidgetTester tester) => tester.getRect(find.byType(FramedCapsuleInput)).bottom;

  Future<void> keyboardUp(WidgetTester tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
  }

  testWidgets('writing brings the whole box, buttons too, above the keyboard', (tester) async {
    const pc = Device(id: 'pc', name: 'Office PC', type: 'desktop', ip: '10.0.0.97', port: 4000);
    await show(tester, pc);
    await tester.tap(find.byType(TextField));
    await keyboardUp(tester);
    expect(boxBottom(tester), lessThanOrEqualTo(_height - _keyboard));
  });

  testWidgets('a message arriving while writing does not push the box under the keyboard', (tester) async {
    const pc = Device(id: 'pc2', name: 'Home PC', type: 'desktop', ip: '10.0.0.98', port: 4000);
    await show(tester, pc);
    await tester.tap(find.byType(TextField));
    await keyboardUp(tester);
    for (var i = 0; i < 4; i++) {
      ApexCore.instance.chat.receive(pc.chatPeer, 'Home PC', 'message $i\nwith a second line');
      await tester.pumpAndSettle();
    }
    expect(boxBottom(tester), lessThanOrEqualTo(_height - _keyboard));
  });
}
