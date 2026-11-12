import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/shared/apex_icons.dart';
import 'package:apex_file_share/shared/device_card.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_send_device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The TV device card is the shared card, by the remote, with no phone
/// widget inside (owner decision: OK grows it in place, no dialog).
void main() {
  const device = Device(id: 'http:192.168.1.20', name: 'Office PC', type: 'desktop', ip: '192.168.1.20');

  late List<String> calls;

  Widget host({bool isActive = true, bool isPinned = false, bool busy = false, Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TVDeviceCard(
              device: device,
              isActive: isActive,
              isPinned: isPinned,
              isGloballyBusy: busy,
              autofocus: true,
              onPin: () => calls.add('pin'),
              onUnpin: () => calls.add('unpin'),
            ),
          ),
        ),
      );

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  bool focused(WidgetTester tester, Finder f) => Focus.of(tester.element(f)).hasPrimaryFocus;

  /// Up from the opened card's first send reaches the head: its menu.
  Future<void> upToMenu(WidgetTester tester) async {
    for (var i = 0; i < 3 && !focused(tester, find.byIcon(ApexIcons.menu)); i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(focused(tester, find.byIcon(ApexIcons.menu)), isTrue, reason: 'the remote reaches ⋮');
  }

  /// OK on ⋮ opens the menu; the remote then walks it to [label].
  Future<void> choose(WidgetTester tester, String label) async {
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text(label), findsOneWidget);
    for (var i = 0; i < 4 && !Focus.of(tester.element(find.text(label))).hasFocus; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(Focus.of(tester.element(find.text(label))).hasFocus, isTrue);
    await press(tester, LogicalKeyboardKey.select);
  }

  setUp(() {
    calls = [];
    foldDeviceCards();
  });

  testWidgets('no phone widget is inside the TV card', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Office PC'), findsOneWidget);
    expect(find.text('192.168.1.20'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ConnectionWidget'), findsNothing);
    expect(find.byType(DeviceCard), findsOneWidget);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('OK opens the card in place: file, app and folder, no dialog ($locale)', (tester) async {
      await tester.pumpWidget(host(locale: locale));
      await press(tester, LogicalKeyboardKey.select);
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(l10n.sendFilesNow), findsOneWidget);
      expect(find.text(l10n.sendApp), findsOneWidget);
      expect(find.text(l10n.sendFolder), findsOneWidget,
          reason: 'Owner decision 2026-11-03: the TV sends a folder too.');
    });
  }

  testWidgets('the remote pins the device from the menu', (tester) async {
    await tester.pumpWidget(host());
    await press(tester, LogicalKeyboardKey.select);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await upToMenu(tester);
    await choose(tester, l10n.pinDevice);
    expect(calls, ['pin']);
  });

  testWidgets('a pinned device offers to unpin', (tester) async {
    await tester.pumpWidget(host(isPinned: true));
    await press(tester, LogicalKeyboardKey.select);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await upToMenu(tester);
    await choose(tester, l10n.unpinDevice);
    expect(calls, ['unpin']);
  });

  testWidgets('an offline device opens no send choices', (tester) async {
    await tester.pumpWidget(host(isActive: false));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.deviceOffline), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text(l10n.sendFilesNow), findsNothing);
    expect(find.text(l10n.sendApp), findsNothing);
  });

  testWidgets('a pinned device that is offline can still be unpinned', (tester) async {
    await tester.pumpWidget(host(isActive: false, isPinned: true));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await press(tester, LogicalKeyboardKey.select);
    // Nothing to send, so the remote lands on the menu.
    expect(focused(tester, find.byIcon(ApexIcons.menu)), isTrue,
        reason: 'An old device that never comes back would stay pinned for good.');
    await choose(tester, l10n.unpinDevice);
    expect(calls, ['unpin']);
  });

  testWidgets('while another send runs, the opened card says so and offers no send', (tester) async {
    await tester.pumpWidget(host(busy: true));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text(l10n.chatTransferBusy), findsOneWidget);
    expect(find.text(l10n.sendFilesNow), findsNothing);
  });

  testWidgets('a Nearby device shows a translated link name, not an address', (tester) async {
    const nearby = Device(id: 'nearby:x', name: 'Ali Phone', type: 'phone', ip: '', endpointId: 'x');
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TVDeviceCard(device: nearby)),
    ));
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.directConnection), findsOneWidget);
  });
}
