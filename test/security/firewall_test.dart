@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('the app itself never changes the firewall', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final p = f.path.replaceAll(r'\', '/');
      if (p.endsWith('.dart') &&
          RegExp(r'''['"](netsh|firewall-cmd|ufw)(\.exe)?['"]''').hasMatch(f.readAsStringSync())) {
        hits.add(p);
      }
    }
    expect(hits, isEmpty,
        reason: 'A rule added at launch is repeated every run and no uninstall '
            'knows about it. Firewall changes belong to the installer, with '
            'their removal in the uninstaller.');
  });

  test('every ufw rule the Linux install adds, uninstall deletes', () {
    final added = RegExp(r'ufw allow (\S+)')
        .allMatches(_read('install_linux.sh') + _read('launch_linux.sh'))
        .map((m) => m.group(1))
        .toSet();
    final deleted =
        RegExp(r'ufw delete allow (\S+)').allMatches(_read('uninstall_linux.sh')).map((m) => m.group(1)).toSet();
    expect(added.difference(deleted), isEmpty);
  });

  test('the launch script for development leaves the firewall alone', () {
    expect(RegExp(r'firewall-cmd|ufw').hasMatch(_read('launch_linux.sh')), isFalse,
        reason: 'It opened ports permanently with sudo on every run.');
  });
}
