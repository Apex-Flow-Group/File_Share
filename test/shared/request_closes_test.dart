import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/nearby_messages.dart';
import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/nearby_door.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/home_dialogs.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:apex_file_share/tv/widgets/tv_accept_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the asker stops waiting (no answer in time), the request is closed and
/// a dialog still showing it goes away: a late "Accept" must not look accepted.
const _wait = Duration(milliseconds: 150);

ConnectionRequest _request(List<bool> answers) => ConnectionRequest(
      device: const Device(id: 'http:192.168.1.20', name: 'Ali Phone', type: 'unknown', ip: '192.168.1.20'),
      fileName: 'photo.jpg',
      fileSize: 2048,
      onResponse: answers.add,
    );

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

class _PhoneHost extends StatefulWidget {
  const _PhoneHost(this.request);
  final ConnectionRequest request;

  @override
  State<_PhoneHost> createState() => _PhoneHostState();
}

class _PhoneHostState extends State<_PhoneHost> with HomeDialogs {
  @override
  void onOpenFilesFromSheet([String? filePath]) {}

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => showConnectionRequestDialog(widget.request),
          child: const Text('open'),
        ),
      );
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  group('every door closes its request when it stops waiting', () {
    test('HTTP receive: no answer in time', () async {
      HttpOverrides.global = null;
      final root = await Directory.systemTemp.createTemp('apex_close_http_');
      final shown = <ConnectionRequest>[];
      final receive = ReceiveHttp(
        gate: ReceiveGate(),
        store: ReceiveStore(tempFolder: () async => root, place: (t, n) async => t.path),
        onConnectionRequest: shown.add,
        onFileReceived: (_) {},
        decisionTimeout: _wait,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (!await receive.handle(req)) {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
      try {
        final client = HttpClient();
        final req = await client.postUrl(Uri.http('127.0.0.1:${server.port}', ApexProtocol.offerPath));
        req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
        final body = utf8.encode(jsonEncode({
          'id': 'test-phone',
          'name': 'Phone',
          'files': [
            {'name': 'a.txt', 'size': 1}
          ],
        }));
        req.contentLength = body.length;
        req.add(body);
        await (await req.close()).drain<void>();
        client.close(force: true);
        expect(shown.single.isClosed, isTrue);
      } finally {
        await server.close(force: true);
        TransferProgressService().clearProgress();
        await root.delete(recursive: true);
      }
    });

    test('Nearby: no answer to the connection or the offer', () async {
      final shown = <ConnectionRequest>[];
      final door = NearbyDoor(
          onConnectionRequest: shown.add, send: (_, __) async {}, decisionTimeout: _wait);
      await door.mayConnect('ep1', 'Phone');
      await door.onMessage('ep1', {
        'type': NearbyMessage.offer,
        'version': ApexProtocol.version,
        'name': 'Phone',
        'files': [
          {'name': 'a.txt', 'size': 1}
        ],
      });
      expect(shown, hasLength(2));
      expect(shown.every((r) => r.isClosed), isTrue);
    });

    test('Nearby: an answered request is closed too', () async {
      final shown = <ConnectionRequest>[];
      final door = NearbyDoor(
          onConnectionRequest: (r) {
            shown.add(r);
            r.onResponse(true);
          },
          send: (_, __) async {},
          decisionTimeout: _wait);
      await door.mayConnect('ep1', 'Phone');
      expect(shown.single.isClosed, isTrue);
    });

    test('share folder: no answer in time', () async {
      HttpOverrides.global = null;
      final dir = await Directory.systemTemp.createTemp('apex_close_share_');
      final shown = <ConnectionRequest>[];
      final share = ShareFolderHttp(
        isEnabled: () => true,
        allowUploads: () => false,
        getLocalName: () => 'PC',
        service: _TempShareService(dir.path),
        onAccessRequest: shown.add,
        decisionTimeout: _wait,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (!await share.handle(req)) {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
      try {
        final client = HttpClient();
        final req = await client.postUrl(Uri.http('127.0.0.1:${server.port}', ShareFolderHttp.accessPath));
        req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
        req.contentLength = 2;
        req.add(utf8.encode('{}'));
        await (await req.close()).drain<void>();
        client.close(force: true);
        expect(shown.single.isClosed, isTrue);
      } finally {
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    });
  });

  group('a dialog showing a closed request goes away', () {
    testWidgets('TV', (tester) async {
      final answers = <bool>[];
      final request = _request(answers);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => TVAcceptDialog.ask(context, request),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      request.close();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(answers, isNot(contains(true)));
    });

    testWidgets('phone and desktop', (tester) async {
      final answers = <bool>[];
      final request = _request(answers);
      await tester.pumpWidget(_app(_PhoneHost(request)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);

      request.close();
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsNothing);
      expect(answers, isNot(contains(true)));
    });

    testWidgets('a request already closed is not shown at all', (tester) async {
      final request = _request([])..close();
      await tester.pumpWidget(_app(_PhoneHost(request)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsNothing);
    });
  });
}
