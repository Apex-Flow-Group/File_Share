import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/receive/data/receive_http.dart';
import 'package:apex_file_share/features/receive/data/receive_store.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';

/// The real receive code behind a real server on 127.0.0.1, with its own
/// folders and a gate clock the test moves. Every offer is accepted unless
/// [decide] says otherwise (null: the user never answers).
class ReceiveTestServer {
  ReceiveTestServer._(this._root, this._server);

  final Directory _root;
  final HttpServer _server;
  DateTime now = DateTime(2026, 11, 3, 12);
  final shown = <ConnectionRequest>[];
  int get port => _server.port;

  Directory get saveDir => Directory('${_root.path}/save');
  Directory get tempDir => Directory('${_root.path}/tmp');

  static Future<ReceiveTestServer> start({
    bool? Function(ConnectionRequest)? decide,
    Duration? bodyIdleLimit,
  }) async {
    TransferProgressService().clearProgress();
    final root = await Directory.systemTemp.createTemp('apex_receive_server_');
    Directory('${root.path}/tmp').createSync();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = ReceiveTestServer._(root, server);
    final receive = ReceiveHttp(
      gate: ReceiveGate(clock: () => s.now),
      store: ReceiveStore(
        tempFolder: () async => s.tempDir,
        place: (temp, name) async => (await moveIntoFolder(temp, s.saveDir, name)).path,
      ),
      onConnectionRequest: (r) {
        s.shown.add(r);
        final answer = decide == null ? true : decide(r);
        if (answer != null) {
          r.onResponse(answer);
        }
      },
      onFileReceived: (_) {},
      bodyIdleLimit: bodyIdleLimit ?? TransferRules.bodyIdleLimit,
    );
    server.listen((req) async {
      if (!await receive.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return s;
  }

  Future<void> stop() async {
    await _server.close(force: true);
    TransferProgressService().clearProgress();
    await _root.delete(recursive: true);
  }

  /// Offers [files] (name to size) and returns the tokens of the accepted batch.
  Future<List<String>> offer(Map<String, int> files) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.http('127.0.0.1:${_server.port}', ApexProtocol.offerPath));
      req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
      req.write(jsonEncode({
        'name': 'Test Phone',
        'files': [for (final f in files.entries) {'name': f.key, 'size': f.value}],
      }));
      final res = await req.close();
      final json = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      return (json['tokens'] as List).cast<String>();
    } finally {
      client.close(force: true);
    }
  }

  /// Uploads [bytes] with [token] and returns the status. With [midway], the
  /// first half is sent, [midway] runs, then the rest is sent.
  Future<int> upload(String token, List<int> bytes, {Future<void> Function()? midway}) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.http('127.0.0.1:${_server.port}', ApexProtocol.uploadPath));
      req.headers
        ..set(ApexProtocol.versionHeader, '${ApexProtocol.version}')
        ..set(ApexProtocol.tokenHeader, token);
      req.contentLength = bytes.length;
      req.bufferOutput = false;
      final half = bytes.length ~/ 2;
      if (midway != null) {
        req.add(bytes.sublist(0, half));
        await req.flush();
        await midway();
        req.add(bytes.sublist(half));
      } else {
        req.add(bytes);
      }
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  /// Waits until the receiver has opened a temp file, which it does only after
  /// it took the token, so the upload is truly in progress.
  Future<void> uploadStarted() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!tempDir.listSync().any((e) => e.path.endsWith('.part'))) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('the receiver never started writing');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  List<String> saved() => saveDir.existsSync()
      ? (saveDir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort())
      : const [];
}
