@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000);
const _nearbyPhone = Device(id: 'n', name: 'Phone', type: 'phone', endpointId: 'ep1');

FileReceivedEvent _got(String name, int index, int total,
        {String? from = '10.0.0.7', String id = 'p', String sender = 'PC', int batch = 1}) =>
    FileReceivedEvent(
      fileName: name,
      fileSize: 10,
      fromDevice: sender,
      fromAddress: from,
      fromId: id,
      batchId: from == null ? null : batch,
      filePath: '/save/$name',
      batchIndex: index,
      batchTotal: total,
      isLastInBatch: index == total,
    );

void main() {
  group('received files', () {
    late ChatStore store;
    setUp(() => store = ChatStore(send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null)));

    test('a batch is one line in the chat of the address it came from', () {
      store
        ..receivedFile(_got('a.pdf', 1, 3))
        ..receivedFile(_got('b.pdf', 2, 3))
        ..receivedFile(_got('c.pdf', 3, 3));
      final line = store.thread(chatKey('p', '10.0.0.7'))!.messages.single;
      expect(line.isFiles, isTrue);
      expect(line.mine, isFalse);
      expect(line.files.map((f) => f.name), ['a.pdf', 'b.pdf', 'c.pdf']);
      expect(line.files.first.path, '/save/a.pdf');
    });

    test('the next batch is a new line, and each batch counts once as unread', () {
      store
        ..receivedFile(_got('a.pdf', 1, 2))
        ..receivedFile(_got('b.pdf', 2, 2))
        ..receivedFile(_got('c.pdf', 1, 1, batch: 2));
      expect(store.thread(chatKey('p', '10.0.0.7'))!.messages, hasLength(2));
      expect(store.unread(chatKey('p', '10.0.0.7')), 2);
    });

    test('two batches received at once keep their own lines', () {
      // The shared progress counts both together: index and total lie here.
      store
        ..receivedFile(_got('a1.pdf', 1, 3, batch: 7))
        ..receivedFile(_got('b1.pdf', 2, 3, from: '10.0.0.9', batch: 8))
        ..receivedFile(_got('a2.pdf', 1, 1, batch: 7));
      expect(store.thread(chatKey('p', '10.0.0.7'))!.messages.single.files.map((f) => f.name), ['a1.pdf', 'a2.pdf']);
      expect(store.thread(chatKey('p', '10.0.0.9'))!.messages.single.files.map((f) => f.name), ['b1.pdf']);
    });

    test('the line follows the address, not the name the device gave', () {
      store
        ..receivedFile(_got('a.pdf', 1, 1, from: '10.0.0.7', sender: 'Office PC'))
        ..receivedFile(_got('b.pdf', 1, 1, from: '10.0.0.9', sender: 'Office PC', batch: 2));
      expect(store.thread(chatKey('p', '10.0.0.7'))!.messages.single.files.single.name, 'a.pdf');
      expect(store.thread(chatKey('p', '10.0.0.9'))!.messages.single.files.single.name, 'b.pdf');
    });

    test('a file over Nearby has no address and no chat', () {
      store.receivedFile(_got('a.pdf', 1, 1, from: null));
      expect(store.thread(chatKey('p', '10.0.0.7')), isNull);
    });

    test('a blocked device gets no line', () {
      store
        ..block(chatKey('p', '10.0.0.7'))
        ..receivedFile(_got('a.pdf', 1, 1));
      expect(store.thread(chatKey('p', '10.0.0.7'))?.messages ?? const [], isEmpty);
    });

    test('files are not announced: the received sheet already says so', () async {
      final heard = <String>[];
      store.incoming.listen((t) => heard.add(t.address));
      store.receivedFile(_got('a.pdf', 1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(heard, isEmpty);
    });

    test('a device that only sent files can be blocked, like any other', () {
      store.receivedFile(_got('a.pdf', 1, 1));
      expect(store.canBlock(chatKey('p', '10.0.0.7')), isTrue);
    });
  });

  group('sent files', () {
    late List<List<String>> sent;
    late List<SendOutcome> answers;
    late int arrivedBeforeFailure;
    late ChatStore store;

    setUp(() {
      sent = [];
      answers = [];
      arrivedBeforeFailure = 0;
      store = ChatStore(
        send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null),
        sendFilesNow: (files, target, onDelivered) async {
          sent.add([for (final f in files) f.name]);
          final outcome = answers.isEmpty ? SendOutcome.sent : answers.removeAt(0);
          final arrived = outcome == SendOutcome.sent ? files.length : arrivedBeforeFailure;
          for (var i = 1; i <= arrived; i++) {
            onDelivered(i);
          }
          return outcome;
        },
      );
    });

    const files = [ChatFile('a.pdf', 10, '/tmp/a.pdf'), ChatFile('b.pdf', 20, '/tmp/b.pdf')];

    test('a send is a line of mine: sending, then sent', () async {
      final done = store.sendFiles(_pc, files);
      expect(store.thread(_pc.chatKey)!.messages.single.status, ChatStatus.sending);
      expect(await done, SendOutcome.sent);
      final line = store.thread(_pc.chatKey)!.messages.single;
      expect(line.mine, isTrue);
      expect(line.status, ChatStatus.sent);
      expect(line.files.map((f) => f.name), ['a.pdf', 'b.pdf']);
    });

    test('a failed send keeps its reason; retry resends the same line, only when asked', () async {
      answers.add(SendOutcome.busy);
      expect(await store.sendFiles(_pc, files), SendOutcome.busy);
      final line = store.thread(_pc.chatKey)!.messages.single;
      expect(line.filesFailure, SendOutcome.busy);
      expect(sent, hasLength(1));
      await store.retryFiles(_pc, line);
      expect(sent, hasLength(2));
      expect(line.status, ChatStatus.sent);
      expect(store.thread(_pc.chatKey)!.messages, hasLength(1));
    });

    test('a batch cut short resumes with the files that did not arrive, not all again', () async {
      const three = [
        ChatFile('a.pdf', 10, '/tmp/a.pdf'),
        ChatFile('b.pdf', 10, '/tmp/b.pdf'),
        ChatFile('c.pdf', 10, '/tmp/c.pdf'),
      ];
      answers.add(SendOutcome.failed);
      arrivedBeforeFailure = 1;
      await store.sendFiles(_pc, three);
      final line = store.thread(_pc.chatKey)!.messages.single;
      expect(line.delivered, 1);
      await store.retryFiles(_pc, line);
      expect(sent, [
        ['a.pdf', 'b.pdf', 'c.pdf'],
        ['b.pdf', 'c.pdf'],
      ], reason: 'a.pdf already arrived: sending it again makes a copy there');
      expect(line.delivered, 3);
      expect(line.status, ChatStatus.sent);
    });

    test('no retry where it fails the same way again', () async {
      for (final o in [SendOutcome.declined, SendOutcome.updateRequired, SendOutcome.cancelled,
          SendOutcome.tooManyFiles, SendOutcome.noSpace]) {
        expect(ChatStore.retryHelps(o), isFalse, reason: '$o');
      }
      answers.add(SendOutcome.declined);
      await store.sendFiles(_pc, files);
      await store.retryFiles(_pc, store.thread(_pc.chatKey)!.messages.single);
      expect(sent, hasLength(1));
    });

    test('a send that throws ends as failed, never "sending" for ever', () async {
      final throwing = ChatStore(
        send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null),
        sendFilesNow: (files, target, onDelivered) => throw const FileSystemException('disk gone'),
      );
      expect(await throwing.sendFiles(_pc, files), SendOutcome.failed);
      expect(throwing.thread(_pc.chatKey)!.messages.single.status, ChatStatus.failed);
    });

    test('a text retry never resends a file line as text', () async {
      answers.add(SendOutcome.failed);
      await store.sendFiles(_pc, files);
      await store.retry(_pc, store.thread(_pc.chatKey)!.messages.single);
      expect(sent, hasLength(1));
    });

    test('Nearby and blocked devices are sent to without a line', () async {
      await store.sendFiles(_nearbyPhone, files);
      store.block(_pc.chatKey);
      await store.sendFiles(_pc, files);
      expect(sent, hasLength(2));
      expect(store.thread(_pc.chatKey)?.messages ?? const [], isEmpty);
    });
  });

  test('every send and every received file of the core goes through the chat', () {
    final core = File('lib/core/apex_core.dart').readAsStringSync();
    expect('_send.sendFiles('.allMatches(core), hasLength(1),
        reason: 'only inside sendFilesNow; anything else would skip the chat line');
    expect(core, contains('chat.receivedFile(e)'));
    expect(core, contains('size: await File(f.path).length()'),
        reason: 'a retry reads the size now; the old one would cut a grown file and call it sent');
    expect('return _send.sendFiles'.allMatches(core), isEmpty);
  });

  test('a received file carries the real address it came from', () async {
    TransferProgressService().clearProgress();
    final root = await Directory.systemTemp.createTemp('apex_chat_files_');
    Directory('${root.path}/tmp').createSync();
    final events = <FileReceivedEvent>[];
    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => Directory('${root.path}/tmp'),
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
      ),
      onConnectionRequest: (r) => r.onResponse(true),
      onFileReceived: events.add,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (!await receive.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    final client = HttpClient();
    try {
      final offer = await client.postUrl(Uri.http('127.0.0.1:${server.port}', ApexProtocol.offerPath));
      offer.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
      offer.write(jsonEncode({
        'id': 'test-phone',
        'name': 'Someone Else',
        'files': [{'name': 'a.txt', 'size': 3}],
      }));
      final token = ((jsonDecode(await (await offer.close()).transform(utf8.decoder).join()) as Map)['tokens']
          as List).single as String;
      final up = await client.postUrl(Uri.http('127.0.0.1:${server.port}', ApexProtocol.uploadPath));
      up.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..set(ApexProtocol.tokenHeader, token);
      up.contentLength = 3;
      up.add(utf8.encode('abc'));
      await (await up.close()).drain<void>();
      // The receiver answers first, then reports the file.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (events.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(events.single.fromAddress, '127.0.0.1');
      expect(events.single.fromDevice, 'Someone Else', reason: 'the name is only a label');
    } finally {
      client.close(force: true);
      await server.close(force: true);
      TransferProgressService().clearProgress();
      await root.delete(recursive: true);
    }
  });
}
