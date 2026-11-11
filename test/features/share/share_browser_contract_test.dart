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

/// The real browser screen against the real share server on 127.0.0.1: the
/// client must send what the server now requires (version, access, token).
void main() {
  setUpAll(loadPeers);
  late Directory dir;
  late HttpServer server;
  late bool? answer;
  late bool enabled;
  late bool uploads;
  var asked = 0;

  setUp(() async {
    // TestWidgetsFlutterBinding answers 400 to every HTTP request otherwise.
    HttpOverrides.global = null;
    asked = 0;
    enabled = true;
    uploads = true;
    dir = await Directory.systemTemp.createTemp('apex_share_contract_');
    File('${dir.path}/report.pdf').writeAsStringSync('pdf');
    final share = ShareFolderHttp(
      expectedFingerprint: await heardSender(),
      pins: PinStore.memory(),
      isEnabled: () => enabled,
      allowUploads: () => uploads,
      getLocalName: () => 'Office PC',
      service: _TempShareService(dir.path),
      onAccessRequest: (r) {
        asked++;
        final a = answer;
        if (a != null) {
          r.onResponse(a);
        }
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

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShareBrowserScreen(
        device: Device(
            id: 'pc', name: 'Office PC', type: 'desktop', ip: '127.0.0.1', port: server.port, fingerprint: testReceiver.fingerprint),
        clientContext: senderContext(),
        localId: 'phone',
      ),
    ));
    for (var i = 0; i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      // The TLS handshake runs on timers, which only move when time does.
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('when the other user agrees, the folder is listed', (tester) async {
    answer = true;
    await open(tester);
    expect(asked, 1);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.upload_rounded), findsOneWidget);
  });

  testWidgets('when the other user agreed to downloads only, there is no upload button',
      (tester) async {
    answer = true;
    uploads = false;
    await open(tester);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.upload_rounded), findsNothing,
        reason: 'The upload would be sent whole and then refused.');
  });

  testWidgets('when the other user refuses, the screen says so', (tester) async {
    answer = false;
    await open(tester);
    expect(asked, 1);
    expect(find.text('report.pdf'), findsNothing);
    expect(find.text('The owner of the other device refused to open their shared folder'),
        findsOneWidget);
    expect(find.text('Device unreachable'), findsNothing,
        reason: 'The device answered; it is reachable.');
  });

  testWidgets('when the other user does not answer, the screen does not say refused',
      (tester) async {
    answer = null;
    await open(tester);
    expect(find.text('The owner of the other device did not answer'), findsOneWidget);
  });

  testWidgets('when the folder is off there, the screen says so, not "update"', (tester) async {
    answer = true;
    enabled = false;
    await open(tester);
    expect(asked, 0);
    expect(find.text('The shared folder is not enabled on the other device'), findsOneWidget);
  });
}
