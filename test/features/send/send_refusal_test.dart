import 'dart:io';

import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../identity/tls_peer.dart';
import '../receive/data/receive_test_server.dart';

/// When the receiver refuses a batch before asking its user, the sender must
/// learn why: "send failed" for a full disk tells the user nothing to do.
void main() {
  setUpAll(loadPeers);
  late Directory root;
  late File file;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('apex_send_refusal_');
    file = File('${root.path}/a.txt')..writeAsStringSync('hello');
  });

  tearDown(() => root.delete(recursive: true));

  Device target(int port) => Device(id: 't', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: port, fingerprint: testReceiver.fingerprint);

  test('a batch bigger than the free space on the receiver is reported as "no space"', () async {
    final s = await ReceiveTestServer.start(freeBytes: 4);
    addTearDown(s.stop);

    final outcome = await SendHttp(getContext: senderContext, getLocalName: () => 'Phone', getLocalId: () => 'test-id')
        .sendFiles([(path: file.path, name: 'a.txt', size: 5)], target(s.port));

    expect(outcome, SendOutcome.noSpace);
    expect(s.shown, isEmpty);
  });

  test('more files than the limit are refused on the sender, before anything is sent', () async {
    final s = await ReceiveTestServer.start();
    addTearDown(s.stop);
    final many = List.generate(
        TransferRules.maxFilesPerBatch + 1, (i) => (path: file.path, name: 'f$i.txt', size: 5));

    final outcome = await SendHttp(getContext: senderContext, getLocalName: () => 'Phone', getLocalId: () => 'test-id').sendFiles(many, target(s.port));

    expect(outcome, SendOutcome.tooManyFiles);
    expect(s.shown, isEmpty);
  });
}
