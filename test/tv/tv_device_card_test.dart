import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_send_device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The TV device card is built for the remote, with no phone widget inside.
void main() {
  const device = Device(id: 'http:192.168.1.20', name: 'Office PC', type: 'desktop', ip: '192.168.1.20');

  late List<String> calls;

  Widget host({bool isActive = true, bool isPinned = false, Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TVDeviceCard(
            device: device,
            isActive: isActive,
            isPinned: isPinned,
            autofocus: true,
            onPin: () => calls.add('pin'),
            onUnpin: () => calls.add('unpin'),
          ),
        ),
      );

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  setUp(() => calls = []);

  testWidgets('no phone widget is inside the TV card', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Office PC'), findsOneWidget);
    expect(find.text('192.168.1.20'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ConnectionWidget'), findsNothing);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('OK opens the send choices: file and app ($locale)', (tester) async {
      await tester.pumpWidget(host(locale: locale));
      await press(tester, LogicalKeyboardKey.select);
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(find.text(l10n.sendFile), findsOneWidget);
      expect(find.text(l10n.sendApp), findsOneWidget,
          reason: 'A TV is always Android: it sends apps, not folders.');
      expect(find.text(l10n.sendFolder), findsNothing);
    });
  }

  testWidgets('the remote pins the device from the choices', (tester) async {
    await tester.pumpWidget(host());
    await press(tester, LogicalKeyboardKey.select);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.pinDevice));
    await tester.pumpAndSettle();
    expect(calls, ['pin']);
  });

  testWidgets('a pinned device offers to unpin', (tester) async {
    await tester.pumpWidget(host(isPinned: true));
    await press(tester, LogicalKeyboardKey.select);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown); // file -> app -> unpin
    expect(Focus.of(tester.element(find.text(l10n.unpinDevice))).hasFocus, isTrue);
    await press(tester, LogicalKeyboardKey.select);
    expect(calls, ['unpin']);
  });

  testWidgets('an offline device opens no send choices', (tester) async {
    await tester.pumpWidget(host(isActive: false));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.deviceOffline), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text(l10n.sendFile), findsNothing);
    expect(find.text(l10n.sendApp), findsNothing);
  });

  testWidgets('a pinned device that is offline can still be unpinned', (tester) async {
    await tester.pumpWidget(host(isActive: false, isPinned: true));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await press(tester, LogicalKeyboardKey.select);
    expect(Focus.of(tester.element(find.text(l10n.unpinDevice))).hasFocus, isTrue,
        reason: 'An old device that never comes back would stay pinned for good.');
    await press(tester, LogicalKeyboardKey.select);
    expect(calls, ['unpin']);
  });

  testWidgets('while another send runs, OK opens nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TVDeviceCard(device: device, isGloballyBusy: true, autofocus: true, onPin: () {}),
      ),
    ));
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(Dialog), findsNothing,
        reason: 'A dialog with only "pin" would not say why sending is gone.');
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
