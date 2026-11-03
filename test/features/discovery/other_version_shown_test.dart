import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/apex_core.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/discovery_packet.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/tv/widgets/tabs/tv_send_device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision: a device on another protocol version is listed, shown
/// disabled with a version message; nothing is sent to it and its folder is
/// not opened. Its packet still opens no door.
String _raw(Map<String, Object?> body) => '${DiscoveryPacket.magic}${jsonEncode(body)}';

const _old = {
  'id': 'pc-old',
  'name': 'Old PC',
  'type': 'desktop',
  'port': 40100,
  'share': true,
};

Device? _read(String raw) =>
    DiscoveryPacket.decode(raw, from: '192.168.1.9', selfId: 'me') ??
    DiscoveryPacket.otherVersion(raw, from: '192.168.1.9', selfId: 'me');

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('the packet', () {
    for (final (label, body) in [
      ('no version at all (a very old copy)', _old),
      ('an older version', {..._old, 'version': ApexProtocol.version - 1}),
      ('a newer version', {..._old, 'version': ApexProtocol.version + 1}),
    ]) {
      test('$label is listed as another version, with no way in', () {
        final d = _read(_raw(body))!;
        expect(d.versionMismatch, isTrue);
        expect(d.name, 'Old PC');
        expect(d.ip, '192.168.1.9');
        expect(d.port, 0, reason: 'No port: nothing can be sent to it by mistake.');
        expect(d.shareEnabled, isFalse);
        expect(d.hasShare, isFalse);
      });
    }

    test('a current packet is not another version', () {
      final d = _read(_raw({..._old, 'version': ApexProtocol.version}))!;
      expect(d.versionMismatch, isFalse);
      expect(d.port, 40100);
    });

    test('the name of another version is cleaned too', () {
      final d = _read(_raw({..._old, 'name': 'Boss${String.fromCharCode(0x202E)}\nPC'}))!;
      expect(d.name, 'Boss PC');
    });

    test('a broken packet, or our own, is still not listed', () {
      for (final raw in [
        'HELLO${jsonEncode(_old)}',
        '${DiscoveryPacket.magic}{not json',
        '${DiscoveryPacket.magic}[1]',
        _raw({..._old, 'id': ''}),
        _raw({..._old, 'name': 5}),
        _raw({..._old, 'id': 'me'}),
      ]) {
        expect(_read(raw), isNull, reason: raw);
      }
    });

    test('the discovery service lists other versions through DiscoveryPacket', () {
      final src = File('lib/services/discovery_service.dart').readAsStringSync();
      expect(src, contains('DiscoveryPacket.otherVersion('));
    });
  });

  test('nothing is sent to a device on another version', () async {
    final dir = await Directory.systemTemp.createTemp('apex_other_version_');
    final file = File('${dir.path}/a.txt')..writeAsStringSync('a');
    final old = _read(_raw(_old))!;
    try {
      expect(await ApexCore.instance.sendFiles([file.path], old), SendOutcome.updateRequired);
      expect(await ApexCore.instance.sendFile(file.path, old), SendOutcome.updateRequired);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  testWidgets('the phone card shows the version message and no send action', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(ConnectionWidget(device: _read(_raw(_old))!)));
    expect(find.text('Old PC'), findsOneWidget);
    expect(find.text(l10n.versionDiffers), findsOneWidget);
    expect(find.text(l10n.sendFile), findsNothing);
    expect(find.text(l10n.browseSharedFolder), findsNothing);
  });

  testWidgets('the phone card header does not look connected', (tester) async {
    await tester.pumpWidget(_app(ConnectionWidget(device: _read(_raw(_old))!)));
    expect(find.text('192.168.1.9'), findsOneWidget, reason: 'the address as received');
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TransportBadge'), findsNothing);
  });

  testWidgets('offline comes first, as on the TV', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(ConnectionWidget(device: _read(_raw(_old))!, isActive: false)));
    expect(find.text('Currently offline'), findsOneWidget);
    expect(find.text(l10n.versionDiffers), findsNothing);
  });

  testWidgets('the TV card shows the version message and offers no send', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(TVDeviceCard(device: _read(_raw(_old))!, autofocus: true, onPin: () {})));
    expect(find.text(l10n.versionDiffers), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sendFile), findsNothing);
    expect(find.text(l10n.sendApp), findsNothing);
  });
}
