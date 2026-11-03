import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

/// What the asker is told must match what happened on the other side.
void main() {
  late Directory dir;
  late HttpServer server;
  late ShareFolderHttp share;
  final asked = <ConnectionRequest>[];
  bool? answer;
  var enabled = true;
  var uploads = false;

  setUp(() async {
    asked.clear();
    answer = true;
    enabled = true;
    uploads = false;
    dir = await Directory.systemTemp.createTemp('apex_share_answer_');
    share = ShareFolderHttp(
      isEnabled: () => enabled,
      allowUploads: () => uploads,
      getLocalName: () => 'Office PC',
      service: _TempShareService(dir.path),
      onAccessRequest: (r) {
        asked.add(r);
        final a = answer;
        if (a != null) {
          r.onResponse(a);
        }
      },
      decisionTimeout: const Duration(milliseconds: 200),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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

  Future<({int status, Map json})> send(String method, String path,
      {String? token, Map<String, String>? query, List<int>? body}) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.http('127.0.0.1:${server.port}', path, query));
      req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
      if (token != null) {
        req.headers.set(ApexProtocol.tokenHeader, token);
      }
      if (body != null) {
        req.contentLength = body.length;
        req.add(body);
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      final json = text.isEmpty ? {} : jsonDecode(text);
      return (status: res.statusCode, json: json is Map ? json : {});
    } finally {
      client.close(force: true);
    }
  }

  Future<Map> access() async =>
      (await send('POST', ShareFolderHttp.accessPath, body: utf8.encode('{"name":"Phone"}'))).json;

  test('a refusal says refused', () async {
    answer = false;
    expect(await access(), {'accepted': false, 'reason': 'refused'});
  });

  test('no answer in time is not called a refusal', () async {
    answer = null;
    expect(await access(), {'accepted': false, 'reason': 'no_answer'});
  });

  test('a request while another waits is not called a refusal', () async {
    answer = null;
    final first = access();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await access(), {'accepted': false, 'reason': 'no_answer'});
    await first;
  });

  test('a folder that is off says so, not "update the app"', () async {
    enabled = false;
    final res = await send('POST', ShareFolderHttp.accessPath, body: [1]);
    expect(res.status, HttpStatus.notFound);
    expect(res.json['error'], ShareFolderHttp.shareOff);
  });

  test('turning the folder off ends access with no request in between', () async {
    final token = (await access())['token'] as String;
    share.revokeAll();
    expect((await send('GET', '/share', token: token)).status, HttpStatus.forbidden);
  });

  test('the question says whether the device could also upload', () async {
    await access();
    uploads = true;
    await access();
    expect(asked.map((r) => r.allowsUploads), [false, true]);
  });

  test('agreeing to downloads only does not allow uploads turned on later', () async {
    final token = (await access())['token'] as String;
    uploads = true;
    final res =
        await send('POST', '/share/upload', token: token, query: {'name': 'x.txt'}, body: [1]);
    expect(res.status, HttpStatus.forbidden);
    expect(dir.listSync(), isEmpty);
  });
}
