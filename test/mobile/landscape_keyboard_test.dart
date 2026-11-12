import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/settings_sheets.dart';
import 'package:apex_file_share/mobile/widgets/home_sidebar.dart';
import 'package:apex_file_share/shared/apex_colors.dart';
import 'package:apex_file_share/shared/apex_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone held sideways (an S23 is about 915 by 427 points) takes the
/// tablet layout, and with the keyboard up little height is left: the rail
/// and the rename dialog overflowed there (seen on the S23).
const _size = Size(915, 427);
// The S23's keyboard sideways, its bar included: 280 reproduced the
// dialog's overflow seen there.
const _keyboard = 280.0;

void main() {
  Future<AppLocalizations> pump(WidgetTester tester, Widget body, {bool keyboard = true}) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    if (keyboard) {
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    }
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      theme: apexTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: body),
    ));
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('ar'));
  }

  Widget rail() => Row(children: [
        TabletRail(
          currentIndex: 0,
          isRunning: true,
          onSelect: (_) {},
          onRefresh: () {},
          onSettings: () {},
          onAbout: () {},
        ),
        const Expanded(child: SizedBox()),
      ]);

  testWidgets('with the keyboard up the rail scrolls instead of overflowing', (tester) async {
    final l10n = await pump(tester, rail());
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byTooltip(l10n.aboutApp), 50,
        scrollable: find.descendant(of: find.byType(TabletRail), matching: find.byType(Scrollable)));
    expect(find.byTooltip(l10n.aboutApp).hitTestable(), findsOneWidget, reason: 'its tools still in reach');
  });

  testWidgets('without the keyboard the rail fills the height, its tools at the foot', (tester) async {
    final l10n = await pump(tester, rail(), keyboard: false);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byTooltip(l10n.aboutApp)).bottom, greaterThan(_size.height - 80));
  });

  testWidgets('its selected page is a lighter surface, not a colour', (tester) async {
    await pump(tester, rail(), keyboard: false);
    final r = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(r.indicatorColor, ApexColors.dark.selected);
  });

  testWidgets('the rename dialog keeps its buttons above the keyboard', (tester) async {
    final l10n = await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => SettingsSheets.showRenameDialog(context, AppLocalizations.of(context)),
            child: const Text('open'),
          ),
        ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final save = find.text(l10n.save);
    expect(save, findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(_size.height - _keyboard));
  });
}
