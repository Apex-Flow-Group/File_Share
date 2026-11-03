import 'dart:io';

import 'package:apex_file_share/platform/private_temp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('apex_private_test_'));
  tearDown(() => root.delete(recursive: true));

  test('a fresh folder each time', () async {
    final a = await createPrivateTemp(root, 'x_');
    final b = await createPrivateTemp(root, 'x_');
    expect(a.path, isNot(b.path));
    expect(a.existsSync() && b.existsSync(), isTrue);
  });

  test('other users of the machine cannot open it (Linux)', () async {
    final dir = await createPrivateTemp(root, 'x_');
    expect(dir.statSync().mode & 0x3F, 0,
        reason: 'Dart creates folders with the umask (usually 0755), '
            'so /tmp/<folder> is readable by every user.');
  }, testOn: 'linux || mac-os');
}
