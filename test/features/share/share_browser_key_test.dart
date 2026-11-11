import 'dart:io';

import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/share_browser_screen.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

/// The shared-folder browser talks to another device by the rule a send
/// follows (PinStore.shownKeyChanged, pinShown): a device showing another key
/// than the one pinned for its id is not asked and nothing is read from it;
/// one with no pin gets the key it showed pinned once its user agrees.
/// The real screen against the real share server on 127.0.0.1.
void main() {
  setUpAll(loadPeers);
  late Directory dir;
  late HttpServer server;
  late PinStore pins;
  var asked = 0;

  setUp(() async {
    // TestWidgetsFlutterBinding answers 400 to every HTTP request otherwise.
    HttpOverrides.global = null;
    asked = 0;
    pins = PinStore.memory();
    dir = await Directory.systemTemp.createTemp('apex_share_key_');
    File('${dir.path}/report.pdf').writeAsStringSync('pdf');
    final share = ShareFolderHttp(
      expectedFingerprint: await heardSender(),
      pins: PinStore.memory(),
      isEnabled: () => true,
      allowUploads: () => true,
      getLocalName: () => 'Office PC',
      service: _TempShareService(dir.path),
      onAccessRequest: (r) {
        asked++;
        r.onResponse(true);
      },
      decisionTimeout: const Duration(milliseconds: 200),
    );
    server = await bindReceiver();
    server.listen((req) async {
      if (!await share.handle(req)) {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  Future<AppLocalizations> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShareBrowserScreen(
        device: Device(
            id: 'pc', name: 'Office PC', type: 'desktop', ip: '127.0.0.1', port: server.port, fingerprint: testReceiver.fingerprint),
        clientContext: senderContext(),
        localId: 'phone',
        pins: pins,
      ),
    ));
    for (var i = 0; i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      // The TLS handshake runs on timers, which only move when time does.
      await tester.pump(const Duration(milliseconds: 10));
    }
    return AppLocalizations.of(tester.element(find.byType(ShareBrowserScreen)));
  }

  testWidgets('a device showing another key than its pin is not asked, and its folder is not opened',
      (tester) async {
    await tester.runAsync(() => pins.pin('pc', testSender.fingerprint));
    final l10n = await open(tester);
    expect(asked, 0, reason: 'nothing left this device');
    expect(find.text('report.pdf'), findsNothing);
    expect(find.text(l10n.shareNewKey), findsOneWidget);
    expect(pins.pinned('pc'), testSender.fingerprint, reason: 'the pin is never written over here');
  });

  testWidgets('a device with no pin is opened, and the key it showed is pinned', (tester) async {
    await open(tester);
    expect(asked, 1);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(pins.pinned('pc'), testReceiver.fingerprint);
  });

  testWidgets('a device showing its pinned key is opened as before', (tester) async {
    await tester.runAsync(() => pins.pin('pc', testReceiver.fingerprint));
    await open(tester);
    expect(asked, 1);
    expect(find.text('report.pdf'), findsOneWidget);
  });
}
