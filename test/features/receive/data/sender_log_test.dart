@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/chat/logic/block_list.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/data/sender_log.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/services/file_operations_service.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../identity/tls_peer.dart';

/// Who sent each received file, behind the real file door on 127.0.0.1:
/// written only once the file is in its final place, with the fingerprint
/// of the certificate the sender showed, and gone with the file.
void main() {
  late TlsPeer me;
  late TlsPeer phone;
  late Directory root;
  late HttpServer server;
  late BlockList blocks;
  late SenderLog log;
  late File logFile;

  setUpAll(() async {
    me = await TlsPeer.create();
    phone = await TlsPeer.create();
  });

  setUp(() async {
    TransferProgressService().clearProgress();
    root = await Directory.systemTemp.createTemp('apex_sender_log_');
    Directory('${root.path}/tmp').createSync();
    logFile = File('${root.path}/app/senders.json');
    log = await SenderLog.open(logFile);
    final pins = PinStore.memory();
    blocks = BlockList(pins);
    final receive = ReceiveHttp(
      gate: ReceiveGate(),
      store: ReceiveStore(
        tempFolder: () async => Directory('${root.path}/tmp'),
        place: (temp, name) async => (await moveIntoFolder(temp, Directory('${root.path}/save'), name)).path,
      ),
      onConnectionRequest: (r) => r.onResponse(true),
      onFileReceived: (_) {},
      expectedFingerprint: (id, address) => id == 'phone' ? phone.fingerprint : null,
      pins: pins,
      blocks: blocks,
      senders: log,
    );
    server = await me.bind([phone]);
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
    await log.saved;
    await root.delete(recursive: true);
  });

  Uri at(String path) => Uri.https('127.0.0.1:${server.port}', path);

  Future<List<String>> offer(HttpClient client, Map<String, int> files) async {
    final req = await client.postUrl(at(ApexProtocol.offerPath));
    req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
    req.write(jsonEncode({
      'id': 'phone',
      'name': 'Ali Phone',
      'files': [for (final f in files.entries) {'name': f.key, 'size': f.value}],
    }));
    final json = jsonDecode(await (await req.close()).transform(utf8.decoder).join()) as Map;
    return (json['tokens'] as List).cast<String>();
  }

  /// With [midway], half is sent, [midway] runs, then the rest.
  Future<int> upload(HttpClient client, String token, List<int> bytes, {Future<void> Function()? midway}) async {
    final req = await client.postUrl(at(ApexProtocol.uploadPath));
    req.headers
      ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
      ..set(ApexProtocol.tokenHeader, token);
    req
      ..contentLength = bytes.length
      ..bufferOutput = false;
    if (midway != null) {
      req.add(bytes.sublist(0, bytes.length ~/ 2));
      await req.flush();
      await midway();
      req.add(bytes.sublist(bytes.length ~/ 2));
    } else {
      req.add(bytes);
    }
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  Future<void> uploadStarted() async {
    final temp = Directory('${root.path}/tmp');
    for (var i = 0; i < 500 && temp.listSync().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(temp.listSync(), isNotEmpty, reason: 'the upload had begun');
  }

  String savedPath(String name) => '${root.path}/save${Platform.pathSeparator}$name';

  test('a complete file gets a line with the name and the key the sender showed, kept on disk', () async {
    final client = phone.client(me);
    addTearDown(() => client.close(force: true));
    final tokens = await offer(client, {'a.txt': 4});
    final before = DateTime.now().toUtc();

    expect(await upload(client, tokens[0], [1, 2, 3, 4]), HttpStatus.ok);

    final line = log.of(savedPath('a.txt'));
    expect(line, isNotNull);
    expect(line!.name, 'Ali Phone');
    expect(line.fingerprint, phone.fingerprint, reason: 'the certificate fingerprint, not the id it gave');
    expect(line.at.isBefore(before), isFalse);
    await log.saved;
    final reopened = await SenderLog.open(logFile);
    expect(reopened.of(savedPath('a.txt'))?.fingerprint, phone.fingerprint);
    expect(logFile.readAsStringSync(), isNot(contains('"phone"')), reason: 'the id it gave is not kept');
  });

  test('a cancelled or blocked file gets no line', () async {
    final client = phone.client(me);
    addTearDown(() => client.close(force: true));
    var tokens = await offer(client, {'a.txt': 4});
    final cancelled = await upload(client, tokens[0], [1, 2, 3, 4], midway: () async {
      await uploadStarted();
      TransferProgressService().cancelReceive();
    });
    expect(cancelled, 499);
    TransferProgressService().clearProgress();

    tokens = await offer(client, {'b.txt': 4});
    await upload(client, tokens[0], [1, 2, 3, 4], midway: () async {
      await uploadStarted();
      blocks.block(chatPeer(phone.fingerprint, 'phone', '127.0.0.1'));
    });

    await log.saved;
    expect(Directory('${root.path}/save').existsSync(), isFalse);
    expect(log.of(savedPath('a.txt')), isNull);
    expect(log.of(savedPath('b.txt')), isNull);
    expect(logFile.existsSync(), isFalse, reason: 'nothing was written');
  });

  test('deleting the file in the app deletes its line', () async {
    final client = phone.client(me);
    addTearDown(() => client.close(force: true));
    final tokens = await offer(client, {'a.txt': 4});
    await upload(client, tokens[0], [1, 2, 3, 4]);
    expect(log.of(savedPath('a.txt')), isNotNull);

    final deleted = await FileOperationsService(senders: log).deleteFiles({savedPath('a.txt')});

    expect(deleted, 1);
    await log.saved;
    expect((await SenderLog.open(logFile)).of(savedPath('a.txt')), isNull);
    expect(logFile.readAsStringSync(), isNot(contains('a.txt')));
  });

  test('a file deleted outside the app shows no line, and its line is cleaned', () async {
    final client = phone.client(me);
    addTearDown(() => client.close(force: true));
    final tokens = await offer(client, {'a.txt': 4, 'b.txt': 4});
    await upload(client, tokens[0], [1, 2, 3, 4]);
    await upload(client, tokens[1], [1, 2, 3, 4]);
    await log.saved;

    File(savedPath('a.txt')).deleteSync();
    File(savedPath('b.txt')).deleteSync();

    expect(log.of(savedPath('a.txt')), isNull, reason: 'checked when shown');
    log.prune();
    await log.saved;
    expect(logFile.readAsStringSync(), isNot(contains('a.txt')));
    expect(logFile.readAsStringSync(), isNot(contains('b.txt')), reason: 'cleaned when the list is read');
  });

  test('the path the file was placed at finds its line whichever slash the list uses', () async {
    final file = File('${root.path}/save/Images/x.png')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    log.record('${root.path}/save/Images/x.png'.replaceAll('/', r'\'), name: 'Ali Phone', fingerprint: phone.fingerprint);
    if (Platform.pathSeparator == r'\') {
      expect(log.of(file.path.replaceAll('/', r'\')), isNotNull);
    }
    expect(log.of(file.path.replaceAll(r'\', '/')), isNotNull);
  });

  test('a damaged log file stops nothing: it reads as empty and the next line replaces it', () async {
    for (final junk in ['{not json', '[]', '{"lines": {"a": 5, "b": {"name": 1}}}', '']) {
      logFile
        ..createSync(recursive: true)
        ..writeAsStringSync(junk);
      final damaged = await SenderLog.open(logFile);
      expect(damaged.of('${root.path}/a'), isNull, reason: junk);
      final kept = File('${root.path}/kept.txt')..writeAsStringSync('x');
      damaged.record(kept.path, name: 'Ali Phone', fingerprint: phone.fingerprint);
      await damaged.saved;
      expect((await SenderLog.open(logFile)).of(kept.path)?.name, 'Ali Phone', reason: junk);
    }
  });
}
