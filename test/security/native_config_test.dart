@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Android (phone and TV)', () {
    const manifest = 'android/app/src/main/AndroidManifest.xml';
    const netConfig = 'android/app/src/main/res/xml/network_security_config.xml';
    const filePaths = 'android/app/src/main/res/xml/file_paths.xml';
    const activity =
        'android/app/src/main/kotlin/com/apexflow/tools/transfer/MainActivity.kt';

    test('plain (unencrypted) traffic is not allowed to every host', () {
      final base = RegExp(r'<base-config[^>]*cleartextTrafficPermitted="true"')
          .hasMatch(_read(netConfig));
      final app = RegExp(r'android:usesCleartextTraffic="true"').hasMatch(_read(manifest));
      expect([if (base) '$netConfig: base-config', if (app) '$manifest: usesCleartextTraffic'],
          isEmpty,
          reason: 'Any code in the app may then talk plain HTTP to the internet. '
              'Note: the <domain> entries with /16 and /12 are not valid and match nothing.');
    });

    test('the FileProvider does not expose whole storage areas', () {
      final broad = RegExp(r'<(external-path|files-path|cache-path)[^>]*path="\.?/?"')
          .allMatches(_read(filePaths))
          .map((m) => m.group(1))
          .toList();
      expect(broad, isEmpty,
          reason: 'path="." shares all of shared storage or all private app files '
              'through any URI the app grants.');
    });

    test('app data is not copied into device and cloud backups', () {
      expect(RegExp(r'android:allowBackup="false"').hasMatch(_read(manifest)), isTrue,
          reason: 'allowBackup defaults to true: device names and pinned IPs go to backups.');
    });

    test('a name from another app is cleaned before it becomes a path', () {
      final src = _read(activity);
      final fn = RegExp(r'fun copyUriToCache[\s\S]*?\r?\n    \}\r?\n').firstMatch(src)?.group(0) ?? '';
      expect(fn, isNotEmpty);
      expect(RegExp(r'File\(destDir,\s*fileName\)').hasMatch(fn) &&
              !RegExp(r'safeFileName\(').hasMatch(fn),
          isFalse,
          reason: 'DISPLAY_NAME comes from the sharing app. "../../shared_prefs/x.xml" '
              'overwrites this app\'s private settings ("Dirty Stream").');
    });

    test('a shared file cannot point into this app\'s private folder', () {
      final src = _read(activity);
      final fn = RegExp(r'fun copyUriToCache[\s\S]*?\r?\n    \}\r?\n').firstMatch(src)?.group(0) ?? '';
      expect(RegExp(r'uri\.scheme\s*[!=]=\s*"file"|scheme != "content"').hasMatch(fn), isTrue,
          reason: 'EXTRA_STREAM accepts file:///data/data/<this app>/..., which the app '
              'can read, so its private files enter the send list.');
    });
  });

  group('Windows', () {
    test('the firewall rule does not open the app on company (domain) networks', () {
      final main = _read('lib/main.dart');
      expect(RegExp(r'profile=[^\x27"]*domain').hasMatch(main), isFalse,
          reason: 'lib/main.dart adds an inbound allow rule with profile=private,domain: '
              'on a company network every machine can reach the app.');
    });

    test('whatever the app adds to the firewall, uninstall removes', () {
      final adds = _read('lib/main.dart').contains("'add'") &&
          _read('lib/main.dart').contains("'rule'");
      final iss = _read('windows/apex_file_share_setup.iss');
      final removes = RegExp(r'delete\s+rule', caseSensitive: false).hasMatch(iss);
      expect(!adds || removes, isTrue,
          reason: 'The rule is added on every launch and never deleted.');
    });
  });

  group('Linux', () {
    const scripts = ['install_linux.sh', 'launch_linux.sh'];
    // The app uses UDP 45679 for discovery and a random TCP port for transfer.
    const appPorts = {'45679/udp'};

    test('scripts open only the ports the app really uses', () {
      final opened = <String>[];
      for (final s in scripts) {
        for (final m in RegExp(r'--add-port=(\d+/(?:tcp|udp))').allMatches(_read(s))) {
          if (!appPorts.contains(m.group(1))) {
            opened.add('$s: ${m.group(1)}');
          }
        }
      }
      expect(opened, isEmpty,
          reason: 'These ports are opened permanently but the app never listens on them; '
              'any other program on the machine gets them for free.');
    });

    test('uninstall closes every port the install opened', () {
      final added = RegExp(r'--add-port=(\S+)')
          .allMatches(scripts.map(_read).join('\n'))
          .map((m) => m.group(1))
          .toSet();
      final removed = RegExp(r'--remove-port=(\S+)')
          .allMatches(_read('uninstall_linux.sh'))
          .map((m) => m.group(1))
          .toSet();
      expect(added.difference(removed), isEmpty);
    });
  });

  group('Windows and Linux clipboard', () {
    test('copied text is never written to a file on disk', () {
      final hits = <String>[];
      for (final path in ['windows/runner/flutter_window.cpp', 'linux/runner/my_application.cc']) {
        final lines = _read(path).split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (RegExp(r'apex_clip_.*txt|"txt"').hasMatch(lines[i])) {
            hits.add('$path:${i + 1}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'Every copied text (passwords too) lands in %TEMP% or /tmp '
              'and is only deleted after a send.');
    });
  });

  group('Project folder', () {
    test('no stand-alone file server is left in the project', () {
      final hits = <String>[];
      for (final f in Directory('.').listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (p.contains('/build/') || p.contains('/.dart_tool/') || p.contains('/.git/') ||
            p.contains('/ephemeral/') || p.startsWith('./test/')) {
          continue;
        }
        if (!(p.endsWith('.py') || p.endsWith('.sh') || p.endsWith('.bat') || p.endsWith('.ps1'))) {
          continue;
        }
        final text = f.readAsStringSync();
        if (RegExp(r'http\.server|SimpleHTTPRequestHandler|python3? -m http').hasMatch(text)) {
          hits.add(p);
        }
      }
      expect(hits, isEmpty,
          reason: 'A server with no password that lists a folder to the whole network.');
    });
  });
}
