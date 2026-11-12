import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/shared/device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Owner decision: the opened head was three buttons wide and cut the name to
// a few letters, so it holds the fold arrow and one menu.
const _pc = Device(
    id: 'p', name: 'Office PC', type: 'desktop', ip: '192.168.8.97', port: 4000, shareEnabled: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(foldDeviceCards);

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

  testWidgets('the menu and the fold arrow are one capsule, and ⋮ turns to ✕ while open',
      (tester) async {
    final l10n = await open(tester);
    final capsule = find.ancestor(
      of: find.byIcon(Icons.more_vert_rounded),
      matching: find.byWidgetPredicate((w) =>
          w is Container && (w.decoration as BoxDecoration?)?.borderRadius == BorderRadius.circular(24)),
    );
    expect(capsule, findsOneWidget);
    expect(find.descendant(of: capsule, matching: find.byIcon(Icons.expand_less_rounded)), findsOneWidget);
    expect(tester.getSize(capsule).height, 48);

    await tester.tap(find.byTooltip(l10n.deviceOptions));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tapAt(const Offset(10, 2300));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
  });

  testWidgets('the online dot is beside the name, over the Wi-Fi badge', (tester) async {
    await open(tester);
    final dot = find.byWidgetPredicate((w) =>
        w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle && w.constraints?.maxWidth == 10);
    expect(dot, findsOneWidget);
    final name = tester.getRect(find.text('Office PC'));
    final d = tester.getRect(dot);
    expect((d.center.dy - name.center.dy).abs(), lessThan(4), reason: 'on the name line');
    // Arabic reads right to left: the dot is at the start, right of the name.
    expect(d.left, greaterThanOrEqualTo(name.right));
    expect(d.center.dx, greaterThan(tester.getCenter(find.byIcon(Icons.expand_less_rounded)).dx),
        reason: 'not among the buttons at the row end');
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
