import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real sender talks to the real receiver over 127.0.0.1.
void main() {
  late Directory root;
  late Directory saveDir;
  late Directory tempDir;
  late HttpServer server;
  late bool accept;
  late void Function() onFileArrived;

  final sender = SendHttp(getLocalName: () => 'Test Phone');

  Device target(int port) =>
      Device(id: 'target', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: port);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('apex_send_http_');
    saveDir = Directory('${root.path}/save');
    tempDir = Directory('${root.path}/tmp')..createSync();
    accept = true;
    onFileArrived = () {};
    TransferProgressService().clearProgress();

    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => tempDir,
        place: (temp, name) async => (await moveIntoFolder(temp, saveDir, name)).path,
      ),
      onConnectionRequest: (r) => r.onResponse(accept),
      onFileReceived: (_) => onFileArrived(),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (!await receive.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    TransferProgressService().clearProgress();
    await root.delete(recursive: true);
  });

  List<({String path, String name, int size})> files(Map<String, String> contents) => [
        for (final e in contents.entries)
          (() {
            final f = File('${root.path}/${e.key}')..writeAsStringSync(e.value);
            return (path: f.path, name: e.key, size: f.lengthSync());
          })(),
      ];

  Map<String, String> saved() => {
        if (saveDir.existsSync())
          for (final f in saveDir.listSync().whereType<File>())
            f.uri.pathSegments.last: f.readAsStringSync(),
      };

  test('three files arrive with their content', () async {
    final outcome = await sender.sendFiles(
        files({'a.txt': 'one', 'b.txt': 'two', 'مرحبا.txt': 'ثلاثة'}), target(server.port));
    expect(outcome, SendOutcome.sent);
    expect(saved(), {'a.txt': 'one', 'b.txt': 'two', 'مرحبا.txt': 'ثلاثة'});
  });

  test('an empty file is sent', () async {
    expect(await sender.sendFiles(files({'empty.txt': ''}), target(server.port)), SendOutcome.sent);
    expect(saved(), {'empty.txt': ''});
  });

  test('when the user refuses, nothing is sent', () async {
    accept = false;
    expect(await sender.sendFiles(files({'a.txt': 'x'}), target(server.port)), SendOutcome.declined);
    expect(saved(), isEmpty);
  });

  test('a receiver on an old version is reported as "update required"', () async {
    // An old copy has no /offer and answers 404.
    final old = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    old.listen((req) async {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    });
    try {
      expect(await sender.sendFiles(files({'a.txt': 'x'}), target(old.port)),
          SendOutcome.updateRequired);
    } finally {
      await old.close(force: true);
    }
  });

  test('a receiver on another version is reported as "update required"', () async {
    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    other.listen((req) async {
      req.response
        ..statusCode = HttpStatus.upgradeRequired
        ..write(jsonEncode({'error': ApexProtocol.updateRequired}));
      await req.response.close();
    });
    try {
      expect(await sender.sendFiles(files({'a.txt': 'x'}), target(other.port)),
          SendOutcome.updateRequired);
    } finally {
      await other.close(force: true);
    }
  });

  test('cancelling after the first file stops the batch', () async {
    onFileArrived = () => TransferProgressService().cancelTransfer();
    final outcome =
        await sender.sendFiles(files({'a.txt': '1', 'b.txt': '2', 'c.txt': '3'}), target(server.port));
    expect(outcome, SendOutcome.cancelled);
    expect(saved().keys, ['a.txt']);
  });

  test('an unreachable receiver fails without hanging', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    expect(await sender.sendFiles(files({'a.txt': 'x'}), target(port)), SendOutcome.failed);
  });
}
