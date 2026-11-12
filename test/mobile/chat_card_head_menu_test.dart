import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Owner decision: the opened head was three buttons wide and cut the name to
// a few letters, so it holds the fold arrow and one menu.
const _pc = Device(
    id: 'p', name: 'Office PC', type: 'desktop', ip: '192.168.8.97', port: 4000, shareEnabled: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(foldChatCards);

  Future<AppLocalizations> open(WidgetTester tester, {VoidCallback? onPin}) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: ConnectionWidget(device: _pc, onPin: onPin ?? () {})),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Office PC'));
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('the opened head shows no folder, block or star of its own', (tester) async {
    final l10n = await open(tester);
    expect(find.byTooltip(l10n.deviceOptions), findsOneWidget);
    expect(find.byIcon(Icons.folder_shared_rounded), findsNothing);
    expect(find.byIcon(Icons.block_rounded), findsNothing);
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
  });

  testWidgets('its menu holds the shared folder, the favourite and block, block last', (tester) async {
    final l10n = await open(tester);
    await tester.tap(find.byTooltip(l10n.deviceOptions));
    await tester.pumpAndSettle();
    final titles = [l10n.sharedFolder, l10n.pinDevice, l10n.chatBlock];
    final ys = [for (final t in titles) tester.getCenter(find.text(t)).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.byType(PopupMenuDivider), findsOneWidget);
  });

  testWidgets('the favourite in the menu pins the device', (tester) async {
    var pinned = 0;
    final l10n = await open(tester, onPin: () => pinned++);
    await tester.tap(find.byTooltip(l10n.deviceOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pinDevice));
    await tester.pumpAndSettle();
    expect(pinned, 1);
  });

  testWidgets('block in the menu still asks first', (tester) async {
    final l10n = await open(tester);
    await tester.tap(find.byTooltip(l10n.deviceOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.chatBlock));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
