import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'receive_test_server.dart';

/// Before the user accepts, a device on the network must not be able to pile
/// up dialogs (a new one could appear under the finger as the user taps) or
/// hold the door open by sending a body that never ends.
void main() {
  const limit = Duration(milliseconds: 300);

  Future<HttpClientRequest> open(int port, String path, {String? token}) async {
    final req = await HttpClient().postUrl(Uri.http('127.0.0.1:$port', path));
    req.headers.set(ApexProtocol.versionHeader, '${ApexProtocol.version}');
    if (token != null) {
      req.headers.set(ApexProtocol.tokenHeader, token);
    }
    return req;
  }

  /// A stalled sender only learns the connection was cut when it writes
  /// again: finishing the body after the limit must fail.
  Future<void> expectCut(HttpClientRequest req, int rest) async {
    await Future<void>.delayed(limit * 3);
    Object? error;
    try {
      req.add(List.filled(rest, 0));
      await req.close();
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull, reason: 'The receiver still waits for a stalled body.');
  }

  Future<int> offer(int port) async {
    final req = await open(port, ApexProtocol.offerPath);
    req.write(jsonEncode({
      'id': 'test-phone',
      'name': 'Phone',
      'files': [
        {'name': 'a.txt', 'size': 4},
      ],
    }));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  test('while one offer waits for the user, another is refused at once and no second dialog opens',
      () async {
    final s = await ReceiveTestServer.start(decide: (_) => null);
    addTearDown(s.stop);

    final first = offer(s.port);
    while (s.shown.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final second = await offer(s.port).timeout(const Duration(seconds: 5));

    expect(second, HttpStatus.tooManyRequests);
    expect(s.shown, hasLength(1));
    s.shown.single.onResponse(false);
    expect(await first, HttpStatus.ok);
  });

  test('after the first offer is answered, the next one is shown', () async {
    final s = await ReceiveTestServer.start(decide: (_) => false);
    addTearDown(s.stop);

    expect(await offer(s.port), HttpStatus.ok);
    expect(await offer(s.port), HttpStatus.ok);
    expect(s.shown, hasLength(2));
  });

  test('an offer body that stops arriving is dropped, and asks nothing', () async {
    final s = await ReceiveTestServer.start(bodyIdleLimit: limit);
    addTearDown(s.stop);

    final req = await open(s.port, ApexProtocol.offerPath);
    req.contentLength = 100;
    final start = utf8.encode('{"files":');
    req.add(start);
    await req.flush();
    await expectCut(req, 100 - start.length);

    expect(s.shown, isEmpty);
  });

  test('an upload that stops mid-file is dropped, leaves nothing, and frees its batch', () async {
    final s = await ReceiveTestServer.start(bodyIdleLimit: limit);
    addTearDown(s.stop);
    final tokens = await s.offer({'a.txt': 4, 'b.txt': 4});

    final req = await open(s.port, ApexProtocol.uploadPath, token: tokens[0]);
    req.contentLength = 4;
    req.bufferOutput = false;
    req.add([1, 2]);
    await req.flush();
    await s.uploadStarted();
    await expectCut(req, 2);

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (s.tempDir.listSync().isNotEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(s.tempDir.listSync(), isEmpty);
    expect(s.saved(), isEmpty);

    s.now = s.now.add(const Duration(hours: 1));
    expect(await s.upload(tokens[1], const [1, 2, 3, 4]), HttpStatus.forbidden,
        reason: 'A stalled upload kept its batch open for ever.');
  });
}
