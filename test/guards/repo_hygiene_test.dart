@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> _trackedFiles() {
  final r = Process.runSync('git', ['ls-files', '-z']);
  if (r.exitCode != 0) {
    fail('git ls-files failed: ${r.stderr}');
  }
  return (r.stdout as String)
      .split(String.fromCharCode(0))
      .where((p) => p.isNotEmpty)
      .toList();
}

const _binaryExtensions = {
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.icns', '.bmp',
  '.ttf', '.otf', '.woff', '.woff2', '.jar', '.zip', '.apk', '.aab',
  '.exe', '.dll', '.so', '.jks', '.keystore', '.pdf', '.mp3', '.mp4',
};

final _machinePath = <String, RegExp>{
  'Windows user folder': RegExp(r'[A-Za-z]:(\\{1,2}|/)(Users|Documents and Settings)(\\{1,2}|/)', caseSensitive: false),
  'Windows install folder': RegExp(r'[A-Za-z]:(\\{1,2}|/)Program Files', caseSensitive: false),
  'Linux home folder': RegExp(r'/home/[A-Za-z0-9._-]+/'),
  'macOS home folder': RegExp(r'(^|[\s"' "'" r'=(])/Users/[A-Za-z0-9._-]+/'),
  'SDK path in properties': RegExp(r'^\s*(flutter\.sdk|sdk\.dir|org\.gradle\.java\.home)\s*=', multiLine: true),
};

final _machineFiles = <String, RegExp>{
  'build output': RegExp(r'(^|/)(build|\.dart_tool)/'),
  'generated plugin folder': RegExp(r'(^|/)ephemeral/'),
  'local SDK settings': RegExp(r'(^|/)local\.properties$'),
  'IDE project files': RegExp(r'(^|/)\.idea/|\.iml$'),
  'signing secrets': RegExp(r'(^|/)key\.properties$|\.(jks|keystore|p12|pem)$'),
  'environment secrets': RegExp(r'(^|/)\.env(\..+)?$'),
};

void main() {
  final tracked = _trackedFiles();

  test('no tracked file contains a path of a specific machine', () {
    final hits = <String>[];
    for (final path in tracked) {
      if (path.startsWith('test/guards/')) {
        continue;
      }
      final dot = path.lastIndexOf('.');
      if (dot != -1 && _binaryExtensions.contains(path.substring(dot).toLowerCase())) {
        continue;
      }
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final String text;
      try {
        text = file.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      final lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final rule in _machinePath.entries) {
          if (rule.value.hasMatch(lines[i])) {
            hits.add('$path:${i + 1} (${rule.key})');
          }
        }
      }
    }
    expect(hits, isEmpty,
        reason: 'Machine paths break the build on every other machine and leak '
            'the owner\'s user name in a public repo. Read them from the '
            'environment or an untracked local file instead:\n${hits.join('\n')}');
  });

  test('no build output, local settings or secrets are tracked', () {
    final hits = <String>[];
    for (final path in tracked) {
      for (final rule in _machineFiles.entries) {
        if (rule.value.hasMatch(path)) {
          hits.add('$path (${rule.key})');
        }
      }
    }
    expect(hits, isEmpty,
        reason: 'These files belong to one machine. Untrack them (git rm --cached) '
            'and keep them in .gitignore:\n${hits.join('\n')}');
  });
}
