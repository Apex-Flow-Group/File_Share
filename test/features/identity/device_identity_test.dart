@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/protocol/discovery_packet.dart';
import 'package:apex_file_share/features/identity/device_identity.dart';
import 'package:apex_file_share/features/identity/fingerprint.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/platform/owner_only.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;

  setUp(() async => folder = await Directory.systemTemp.createTemp('apex_identity_test_'));
  tearDown(() async => folder.delete(recursive: true));

  test('the identity is made once and read back on every later run', () async {
    final first = await DeviceIdentity.loadOrCreate(folder);
    final key = File('${folder.path}/${DeviceIdentity.keyFile}').readAsStringSync();
    final second = await DeviceIdentity.loadOrCreate(folder);
    expect(second.fingerprint, first.fingerprint);
    expect(File('${folder.path}/${DeviceIdentity.keyFile}').readAsStringSync(), key,
        reason: 'A second run must not replace the key.');
    expect(first.fingerprint, fingerprintOf(first.certificate));
    expect(isFingerprint(first.fingerprint), isTrue, reason: first.fingerprint);
  });

  test('two installs get two identities', () async {
    final other = await Directory.systemTemp.createTemp('apex_identity_other_');
    addTearDown(() => other.delete(recursive: true));
    expect((await DeviceIdentity.loadOrCreate(other)).fingerprint,
        isNot((await DeviceIdentity.loadOrCreate(folder)).fingerprint));
  });

  test('a damaged key is replaced instead of stopping the app', () async {
    final first = await DeviceIdentity.loadOrCreate(folder);
    File('${folder.path}/${DeviceIdentity.keyFile}').writeAsStringSync('broken');
    final next = await DeviceIdentity.loadOrCreate(folder);
    expect(next.fingerprint, isNot(first.fingerprint));
    expect((await DeviceIdentity.loadOrCreate(folder)).fingerprint, next.fingerprint);
  });

  test('the key is readable by its owner only (Linux, macOS)', () async {
    await DeviceIdentity.loadOrCreate(folder);
    final r = await Process.run('stat', ['-c', '%a', '${folder.path}/${DeviceIdentity.keyFile}', folder.path]);
    expect((r.stdout as String).trim().split(RegExp(r'\s+')), ['600', '700']);
  }, skip: Platform.isLinux ? false : 'chmod is for Linux and macOS; Windows AppData is per user');

  test('on Windows the key stays in the local AppData, which a roaming profile does not copy', () {
    final support = Directory(r'C:\Users\x\AppData\Roaming\apex');
    final dir = identityFolder(support).path;
    expect(dir, startsWith(Platform.environment['LOCALAPPDATA']!));
    expect(dir.toLowerCase(), isNot(contains('download')));
  }, skip: Platform.isWindows ? false : 'Windows only');

  group('discovery', () {
    late DeviceIdentity identity;
    late Device me;

    setUp(() async {
      identity = await DeviceIdentity.loadOrCreate(folder);
      me = Device(
          id: 'pc-1',
          name: 'Office PC',
          type: 'desktop',
          ip: '192.168.1.5',
          port: 40100,
          fingerprint: identity.fingerprint,
          certificate: identity.certificate);
    });

    Map<String, Object?> body() =>
        jsonDecode(DiscoveryPacket.encode(me, shareEnabled: false).substring(DiscoveryPacket.magic.length))
            as Map<String, Object?>;

    Device? read(Map<String, Object?> b) {
      final raw = '${DiscoveryPacket.magic}${jsonEncode(b)}';
      return DiscoveryPacket.decode(raw, from: '192.168.1.5', selfId: 'me') ??
          DiscoveryPacket.otherVersion(raw, from: '192.168.1.5', selfId: 'me');
    }

    test('a packet carries the fingerprint and the certificate it is of', () {
      final d = read(body())!;
      expect(d.fingerprint, identity.fingerprint);
      expect(d.certificate, identity.certificate);
      expect(d.versionMismatch, isFalse);
    });

    test('a packet without a valid fingerprint of its certificate is ignored', () {
      final other = List<int>.of(identity.certificate)..[40] ^= 1;
      for (final change in <Map<String, Object?>>[
        {'fp': null},
        {'fp': ''},
        {'fp': identity.fingerprint.toUpperCase()},
        {'fp': identity.fingerprint.substring(1)},
        {'fp': 'g${identity.fingerprint.substring(1)}'},
        {'cert': null},
        {'cert': 'not base64!'},
        {'cert': base64.encode(other)},
        {'cert': base64.encode(List.filled(4096, 1))},
      ]) {
        final b = body()..addAll(change);
        b.removeWhere((_, v) => v == null);
        expect(read(b), isNull, reason: '$change');
      }
    });
  });
}
