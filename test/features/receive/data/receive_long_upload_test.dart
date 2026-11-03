import 'dart:io';

import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'receive_test_server.dart';

/// A big file can take longer than the idle limit. The batch is idle only when
/// no file is moving, so the files after it must still be accepted.
void main() {
  const bytes = [1, 2, 3, 4];
  final longerThanIdle = TransferRules.tokenIdleLimit + const Duration(minutes: 1);

  test('a file longer than the idle limit does not close the rest of the batch', () async {
    final s = await ReceiveTestServer.start();
    addTearDown(s.stop);
    final tokens = await s.offer({'big.bin': 4, 'small.txt': 4});

    expect(
        await s.upload(tokens[0], bytes, midway: () async {
          await s.uploadStarted();
          s.now = s.now.add(longerThanIdle);
        }),
        HttpStatus.ok);
    expect(await s.upload(tokens[1], bytes), HttpStatus.ok,
        reason: 'The idle time was counted from the start of the big file.');
    expect(s.saved(), ['big.bin', 'small.txt']);
  });

  test('another offer during a long file does not drop the batch in progress', () async {
    final s = await ReceiveTestServer.start();
    addTearDown(s.stop);
    final tokens = await s.offer({'big.bin': 4, 'small.txt': 4});

    expect(
        await s.upload(tokens[0], bytes, midway: () async {
          await s.uploadStarted();
          s.now = s.now.add(longerThanIdle);
          await s.offer({'other.txt': 1});
        }),
        HttpStatus.ok);
    expect(await s.upload(tokens[1], bytes), HttpStatus.ok);
  });

  test('a batch left idle after its last file still expires', () async {
    final s = await ReceiveTestServer.start();
    addTearDown(s.stop);
    final tokens = await s.offer({'a.txt': 4, 'b.txt': 4});

    expect(await s.upload(tokens[0], bytes), HttpStatus.ok);
    s.now = s.now.add(longerThanIdle);
    expect(await s.upload(tokens[1], bytes), HttpStatus.forbidden);
  });
}
