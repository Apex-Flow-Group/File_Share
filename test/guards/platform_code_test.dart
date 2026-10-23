@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OS checks and process calls belong in lib/platform/<os>/ only.
/// Files listed here are the existing debt: the number may only go DOWN.
/// When you move code out of a file, lower its number (or delete the line).
const _legacyOsCode = <String, int>{
  'lib/core/apex_core.dart': 6,
  'lib/main.dart': 2,
  'lib/managers/device_manager.dart': 20,
  'lib/managers/permission_manager.dart': 2,
  'lib/mobile/controllers/home_controller.dart': 3,
  'lib/mobile/screens/home_screen.dart': 1,
  'lib/mobile/screens/settings_screen.dart': 2,
  'lib/mobile/screens/settings_sheets.dart': 3,
  'lib/mobile/screens/share_browser_screen.dart': 2,
  'lib/mobile/widgets/connection_widget.dart': 1,
  'lib/mobile/widgets/tabs/receive_tab.dart': 1,
  'lib/screens/about_screen.dart': 6,
  'lib/services/clipboard_monitor_service.dart': 2,
  'lib/services/desktop_notification_service.dart': 3,
  'lib/services/discovery_service.dart': 1,
  'lib/services/file_storage_service.dart': 4,
  'lib/services/share_folder_service.dart': 6,
  'lib/services/update_service.dart': 1,
  'lib/tv/widgets/tabs/tv_send_device_card.dart': 1,
  'lib/utils/file_utils.dart': 10,
  'lib/utils/path_utils.dart': 5,
  'lib/utils/platform_detector.dart': 6,
};

/// TV checks belong in lib/tv/, the router (main.dart) and the detector itself.
const _legacyTvChecks = <String, int>{
  'lib/core/nearby_transfer_receive.dart': 2,
  'lib/screens/splash_screen.dart': 1,
};

final _osCode = RegExp(
    r'Platform\.is(Windows|Linux|MacOS|Android|IOS|Fuchsia)\b|Process\.(run|runSync|start)\(');
final _tvCheck = RegExp(r'\.isTV\b');
final _shell = RegExp(
    r'''Process\.(run|runSync|start)\(\s*['"](cmd|cmd\.exe|powershell|powershell\.exe|pwsh|sh|bash|zsh)['"]|runInShell:\s*true''');

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.replaceAll(r'\', '/').contains('/l10n/generated/'));

String _rel(File f) => f.path.replaceAll(r'\', '/');

Map<String, int> _count(RegExp re, bool Function(String path) allowed) {
  final counts = <String, int>{};
  for (final f in _dartFiles('lib')) {
    final path = _rel(f);
    if (allowed(path)) {
      continue;
    }
    final n = re.allMatches(f.readAsStringSync()).length;
    if (n > 0) {
      counts[path] = n;
    }
  }
  return counts;
}

List<String> _ratchet(Map<String, int> actual, Map<String, int> legacy) {
  final problems = <String>[];
  for (final e in actual.entries) {
    final allowedCount = legacy[e.key];
    if (allowedCount == null) {
      problems.add('${e.key}: ${e.value} new (not allowed here)');
    } else if (e.value > allowedCount) {
      problems.add('${e.key}: ${e.value}, more than the $allowedCount allowed');
    } else if (e.value < allowedCount) {
      problems.add('${e.key}: ${e.value}, lower its number in the list from $allowedCount');
    }
  }
  for (final key in legacy.keys) {
    if (!actual.containsKey(key)) {
      problems.add('$key: 0, delete it from the list');
    }
  }
  return problems;
}

String _asDart(Map<String, int> m) {
  final keys = m.keys.toList()..sort();
  return keys.map((k) => "  '$k': ${m[k]},").join('\n');
}

void main() {
  test('no shell interpreter is started (file names would run as commands)', () {
    final hits = <String>[];
    for (final f in _dartFiles('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_shell.hasMatch(lines[i])) {
          hits.add('${_rel(f)}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty,
        reason: 'cmd/sh parse & | ; in arguments, so a received file named '
            '"report&calc" runs calc. Call the program directly with an '
            'argument list:\n${hits.join('\n')}');
  });

  test('OS-specific code stays in lib/platform/<os>/', () {
    final actual = _count(_osCode, (p) => p.startsWith('lib/platform/'));
    final problems = _ratchet(actual, _legacyOsCode);
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\nCurrent counts:\n${_asDart(actual)}');
  });

  test('TV checks stay in lib/tv/, the router and the detector', () {
    final actual = _count(
        _tvCheck,
        (p) =>
            p.startsWith('lib/tv/') ||
            p == 'lib/main.dart' ||
            p == 'lib/utils/platform_detector.dart');
    final problems = _ratchet(actual, _legacyTvChecks);
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\nCurrent counts:\n${_asDart(actual)}');
  });
}
