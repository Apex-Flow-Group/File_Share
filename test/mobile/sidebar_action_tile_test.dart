import 'dart:async';

import 'package:apex_file_share/mobile/widgets/home_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner request: the sidebar actions light up when pressed and stay lit
/// while what they opened is open (Settings and About open a bottom sheet);
/// Refresh spins its icon until the refresh is done.
void main() {
  Widget host(Widget tile) => MaterialApp(home: Scaffold(body: SizedBox(width: 240, child: tile)));

  Color? background(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(SidebarActionTile), matching: find.byType(AnimatedContainer)));
    return (box.decoration as BoxDecoration?)?.color;
  }

  double turns(WidgetTester tester) => tester
      .widget<RotationTransition>(find.descendant(
          of: find.byType(SidebarActionTile), matching: find.byType(RotationTransition)))
      .turns
      .value;

  testWidgets('lit while what it opened is open, and not after', (tester) async {
    final sheet = Completer<void>();
    await tester.pumpWidget(host(SidebarActionTile(
        icon: Icons.settings_rounded, label: 'Settings', onTap: () => sheet.future)));
    final idle = background(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(background(tester), isNot(idle), reason: 'the sheet is open');

    sheet.complete();
    await tester.pumpAndSettle();
    expect(background(tester), idle, reason: 'the sheet closed');
  });

  testWidgets('Refresh spins until the refresh is done, then stops', (tester) async {
    final refresh = Completer<void>();
    await tester.pumpWidget(host(SidebarActionTile(
        icon: Icons.restart_alt_rounded,
        label: 'Refresh',
        spinWhileBusy: true,
        onTap: () => refresh.future)));
    expect(turns(tester), 0);

    await tester.tap(find.text('Refresh'));
    await tester.pump(const Duration(milliseconds: 100));
    final a = turns(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(turns(tester), isNot(a), reason: 'the icon turns while refreshing');

    refresh.complete();
    await tester.pumpAndSettle();
    expect(turns(tester), 0, reason: 'it ends upright, not mid-turn');
  });

  testWidgets('a quick refresh still shows one visible turn', (tester) async {
    await tester.pumpWidget(host(SidebarActionTile(
        icon: Icons.restart_alt_rounded,
        label: 'Refresh',
        spinWhileBusy: true,
        onTap: () async {})));
    await tester.tap(find.text('Refresh'));
    await tester.pump(); // the first frame starts the clock
    await tester.pump(const Duration(milliseconds: 150));
    expect(turns(tester), greaterThan(0));
    await tester.pumpAndSettle();
    expect(turns(tester), 0);
  });

  testWidgets('a second press while busy does not run it twice', (tester) async {
    var runs = 0;
    final sheet = Completer<void>();
    await tester.pumpWidget(host(SidebarActionTile(
        icon: Icons.info_outline_rounded,
        label: 'About',
        onTap: () {
          runs++;
          return sheet.future;
        })));
    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.tap(find.text('About'));
    await tester.pump();
    expect(runs, 1);
    sheet.complete();
    await tester.pumpAndSettle();
  });
}
