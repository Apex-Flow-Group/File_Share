// Linux is skipped on purpose: PathUtils saves to the real ~/Downloads there
// and a test cannot redirect it, so it would write into the user's files.
@TestOn('windows || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/http_transfer.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory saveRoot;
  late HttpServer server;
  var acceptNext = true;

  String norm(String p) => p.replaceAll(r'\', '/').toLowerCase();

  setUpAll(() async {
    // The test binding answers every HTTP call with 400; this test needs real loopback HTTP.
    HttpOverrides.global = null;
    root = await Directory.systemTemp.createTemp('apex_receive_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
          return '${root.path}/tmp';
        case 'getApplicationDocumentsDirectory':
          return '${root.path}/docs';
      }
      return null;
    });

    final docs = await getApplicationDocumentsDirectory();
    if (!norm(docs.path).startsWith(norm(root.path))) {
      fail('Save folder is not the test folder (${docs.path}); '
          'stopping so no real user file is touched.');
    }
    saveRoot = Directory('${docs.path}/ApexShare');

    final transfer = HttpTransfer(
      getLocalName: () => 'Test PC',
      getLocalIp: () => '127.0.0.1',
      onFileReceived: (_) {},
      onConnectionRequest: (ConnectionRequest r) => r.onResponse(acceptNext),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // Same routing as ApexCore._handleRequest (lib/core/apex_core.dart:242-245).
    server.listen((req) async {
      if (req.method == 'POST' && req.uri.path == '/request') {
        await transfer.handlePermissionRequest(req);
      } else if (req.method == 'POST' && req.uri.path == '/upload') {
        await transfer.handleUpload(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, null);
    await root.delete(recursive: true);
  });

  setUp(() async {
    acceptNext = true;
    TransferProgressService().clearProgress();
    if (saveRoot.existsSync()) {
      await saveRoot.delete(recursive: true);
    }
  });

  Future<int> post(String path, Map<String, String> query, [List<int>? body]) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.http('127.0.0.1:${server.port}', path, query));
      if (body != null) {
        req.contentLength = body.length;
        req.add(body);
      }
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  Future<int> ask(String name, int size) => post('/request',
      {'name': name, 'from': 'Linux PC', 'ip': '127.0.0.1', 'size': '$size'});

  Future<int> upload(String name, List<int> bytes) =>
      post('/upload', {'name': name, 'from': 'Linux PC'}, bytes);

  List<File> saved() => saveRoot.existsSync()
      ? saveRoot.listSync(recursive: true).whereType<File>().toList()
      : <File>[];

  test('an upload with no accepted request is refused and nothing is saved', () async {
    final status = await upload('note.txt', utf8.encode('hello'));
    expect(saved(), isEmpty,
        reason: 'Any device on the network can POST /upload and write into the '
            'user folder without the accept dialog ever appearing.');
    expect(status, isNot(HttpStatus.ok));
  });

  test('an upload after the user refused is refused and nothing is saved', () async {
    acceptNext = false;
    await ask('note.txt', 5);
    final status = await upload('note.txt', utf8.encode('hello'));
    expect(saved(), isEmpty, reason: 'The user said no, yet the file was written.');
    expect(status, isNot(HttpStatus.ok));
  });

  test('a second file with the same name keeps the first one', () async {
    await ask('report.txt', 5);
    await upload('report.txt', utf8.encode('first'));
    await ask('report.txt', 6);
    await upload('report.txt', utf8.encode('second'));

    final contents = saved().map((f) => f.readAsStringSync()).toSet();
    expect(contents, {'first', 'second'},
        reason: 'The first report.txt was replaced silently: '
            'the user lost a file without being asked.');
  });

  test('a name that is valid on Linux arrives on Windows', () async {
    const name = 'notes: draft?.txt';
    await ask(name, 5);
    final status = await upload(name, utf8.encode('hello'));
    expect(status, HttpStatus.ok,
        reason: 'Linux allows : and ? in names, Windows does not; '
            'the receive fails instead of choosing a safe name.');
    expect(saved(), hasLength(1));
  }, skip: Platform.isWindows ? false : 'Windows-only file name rules');

  test('a name with ":" leaves no stray file behind on Windows', () async {
    const name = 'notes: draft?.txt';
    await ask(name, 5);
    await upload(name, utf8.encode('hello'));
    final temp = Directory('${root.path}/tmp/apex_receive');
    final stray = temp.existsSync()
        ? temp
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.startsWith('notes'))
            .toList()
        : <String>[];
    expect(stray, isEmpty,
        reason: 'On Windows ":" opens a hidden stream: an empty "notes" file is '
            'created and never cleaned up.');
  }, skip: Platform.isWindows ? false : 'Windows-only file name rules');

  test('a name that climbs out of the folder stays inside it', () async {
    const name = '../../escape.txt';
    await ask(name, 5);
    await upload(name, utf8.encode('hello'));

    final outside = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !norm(f.path).startsWith(norm(saveRoot.path)))
        .where((f) => !norm(f.path).contains('/tmp/'));
    expect(outside, isEmpty);
  });

  test('a sender that disconnects mid-file leaves no partial file', () async {
    await ask('big.bin', 1000);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    socket.write('POST /upload?name=big.bin&from=Linux%20PC HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\nContent-Length: 1000\r\n\r\n');
    socket.add(List<int>.filled(100, 7));
    await socket.flush();
    await socket.close();
    final temp = Directory('${root.path}/tmp/apex_receive');
    List<File> leftoversNow() => temp.existsSync()
        ? temp
            .listSync()
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last.startsWith('big'))
            .toList()
        : <File>[];
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (leftoversNow().isNotEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    expect(saved(), isEmpty);
    final leftovers = leftoversNow();
    expect(leftovers.map((f) => f.uri.pathSegments.last).toList(), isEmpty,
        reason: 'A half file stays in the temp folder.');
  });
}
