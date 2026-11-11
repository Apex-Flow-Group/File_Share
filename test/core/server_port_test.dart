@TestOn('vm')
library;

import 'dart:io';

import 'package:apex_file_share/core/server_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server takes the port it had last run, so a favorite not discovered
/// is still reached at the address and port it kept; a port taken by another
/// program gives another one, never a failed start.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<HttpServer> bind(int port) => HttpServer.bind(InternetAddress.loopbackIPv4, port);

  test('the second run listens on the port of the first', () async {
    final first = await bindLastPort(await SharedPreferences.getInstance(), bind);
    final port = first.port;
    await first.close(force: true);

    final second = await bindLastPort(await SharedPreferences.getInstance(), bind);
    addTearDown(() => second.close(force: true));
    expect(second.port, port);
  });

  test('a port taken since gives another one, kept for the next run', () async {
    final first = await bindLastPort(await SharedPreferences.getInstance(), bind);
    final port = first.port;
    await first.close(force: true);
    // Another program took it meanwhile.
    final taken = await bind(port);
    addTearDown(() => taken.close(force: true));

    final second = await bindLastPort(await SharedPreferences.getInstance(), bind);
    final moved = second.port;
    expect(moved, isNot(port));
    await second.close(force: true);

    final third = await bindLastPort(await SharedPreferences.getInstance(), bind);
    addTearDown(() => third.close(force: true));
    expect(third.port, moved);
  });
}
