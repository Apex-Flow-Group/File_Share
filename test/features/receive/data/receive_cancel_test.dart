import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'receive_test_server.dart';

void main() {
  const bytes = [1, 2, 3, 4];

  test('after the receiving user cancels, the rest of the batch is refused and nothing more is saved',
      () async {
    final s = await ReceiveTestServer.start();
    addTearDown(s.stop);
    final tokens = await s.offer({'a.txt': 4, 'b.txt': 4, 'c.txt': 4});

    expect(await s.upload(tokens[0], bytes), HttpStatus.ok);
    final cancelled = await s.upload(tokens[1], bytes, midway: () async {
      await s.uploadStarted();
      TransferProgressService().cancelReceive();
    });
    expect(cancelled, 499);
    expect(await s.upload(tokens[2], bytes), HttpStatus.forbidden,
        reason: 'Cancel stopped one file only; the next token still wrote a file.');
    expect(s.saved(), ['a.txt']);
  });

  test('the sender stops the batch when the receiver answers "cancelled" (499)', () async {
    final root = await Directory.systemTemp.createTemp('apex_send_cancel_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      TransferProgressService().clearProgress();
      await root.delete(recursive: true);
    });
    final uploaded = <String>[];
    server.listen((req) async {
      await req.drain<void>();
      final token = req.headers.value(ApexProtocol.tokenHeader);
      final cancel = token == 'b';
      if (req.uri.path == ApexProtocol.uploadPath) {
        uploaded.add(token ?? '');
      }
      req.response
        ..statusCode = cancel ? 499 : HttpStatus.ok
        ..write(jsonEncode(req.uri.path == ApexProtocol.offerPath
            ? {'accepted': true, 'tokens': ['a', 'b', 'c']}
            : cancel
                ? {'error': 'cancelled'}
                : {'success': true}));
      await req.response.close();
    });
    final files = [
      for (final name in ['a.txt', 'b.txt', 'c.txt'])
        (path: (File('${root.path}/$name')..writeAsBytesSync(bytes)).path, name: name, size: 4),
    ];

    final outcome = await SendHttp(getLocalName: () => 'Test Phone').sendFiles(
        files, Device(id: 't', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: server.port));

    expect(outcome, SendOutcome.cancelled);
    expect(uploaded, ['a', 'b'], reason: 'The sender kept sending after the receiver cancelled.');
  });
}
