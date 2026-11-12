import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/home_sidebar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Owner request: the desktop sidebar like his reference, rows lit on hover,
// and a fold button that leaves the icons alone.
void main() {
  Future<AppLocalizations> show(WidgetTester tester,
      {int index = 0, List<int>? picked}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Row(children: [
          DesktopSidebar(
            isRunning: true,
            currentIndex: index,
            onSelect: (i) => picked?.add(i),
            onRefresh: () async {},
            onSettings: () async {},
            onAbout: () async {},
          ),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(locale);
  }

  Color? background(WidgetTester tester, String label) {
    final box = tester.widget<AnimatedContainer>(find
        .ancestor(
            of: find.text(label), matching: find.byType(AnimatedContainer))
        .first);
    return (box.decoration as BoxDecoration?)?.color;
  }

  testWidgets('a row lights while the mouse is over it, and not after',
      (tester) async {
    final l10n = await show(tester);
    final idle = background(tester, l10n.files);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text(l10n.files)));
    await tester.pumpAndSettle();
    final over = background(tester, l10n.files);
    expect(over, isNot(idle));
    expect(over, isNot(background(tester, l10n.send)),
        reason: 'hover is a step below selected');
    await mouse.moveTo(const Offset(1000, 400));
    await tester.pumpAndSettle();
    expect(background(tester, l10n.files), idle);
  });

  testWidgets('a page row selects its page', (tester) async {
    final picked = <int>[];
    final l10n = await show(tester, picked: picked);
    await tester.tap(find.text(l10n.receive));
    expect(picked, [1]);
  });

  testWidgets('folded, it keeps the icons and names them on hover',
      (tester) async {
    final l10n = await show(tester);
    final wide = tester.getSize(find.byType(DesktopSidebar)).width;
    await tester.tap(find.byTooltip(l10n.sidebarCollapse));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byType(DesktopSidebar)).width, lessThan(wide / 2));
    expect(find.text(l10n.files), findsNothing);
    expect(find.byTooltip(l10n.files), findsOneWidget);
    expect(find.byTooltip(l10n.settings), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.sidebarExpand));
    await tester.pumpAndSettle();
    expect(find.text(l10n.files), findsOneWidget);
  });

  testWidgets('whether it is on is said in the app language, not in English',
      (tester) async {
    final l10n = await show(tester);
    expect(find.text(l10n.connected), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });
}
