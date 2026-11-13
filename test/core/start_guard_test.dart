import 'dart:async';
import 'dart:io';

import 'package:apex_file_share/core/start_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// ApexCore.start through its two guards, and what "find devices" does.
void main() {
  group('one start at a time', () {
    test('a second start while the first runs waits for it', () async {
      final once = OneAtATime();
      final gate = Completer<void>();
      var runs = 0;
      Future<void> start() {
        runs++;
        return gate.future;
      }

      final first = once.run(start);
      final second = once.run(start);
      expect(runs, 1);
      gate.complete();
      await Future.wait([first, second]);
      expect(runs, 1);
    });

    test('after a failed start, a retry runs again', () async {
      final once = OneAtATime();
      var runs = 0;
      await expectLater(once.run(() async {
        runs++;
        throw const SocketException('port taken');
      }), throwsA(isA<SocketException>()));
      await once.run(() async => runs++);
      expect(runs, 2);
    });
  });

  group('a failed start closes what it opened', () {
    test('the server bound before the failure is closed, so a retry binds its port',
        () async {
      HttpServer? server;
      Future<void> close() async {
        await server?.close(force: true);
        server = null;
      }

      late int port;
      await expectLater(
          openOrUndo(() async {
            server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            port = server!.port;
            throw const SocketException('discovery socket');
          }, close),
          throwsA(isA<SocketException>()));
      expect(server, isNull);

      final again = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      await again.close(force: true);
    });

    test('a start that succeeds closes nothing', () async {
      var closed = false;
      await openOrUndo(() async {}, () async => closed = true);
      expect(closed, isFalse);
    });
  });

  test('find devices: searches when running, starts after a failure, waits during the first start',
      () {
    expect(findDevicesAction(isRunning: true, startFailed: false), FindDevices.search);
    expect(findDevicesAction(isRunning: false, startFailed: true), FindDevices.start);
    expect(findDevicesAction(isRunning: false, startFailed: false), FindDevices.wait);
  });
}
