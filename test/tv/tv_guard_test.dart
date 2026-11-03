@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Things that do not work with a TV remote, or not at all on Android TV.
final _touchOnly = <String, RegExp>{
  'FilePicker (TVs have no file manager: "No application found")':
      RegExp(r'\bFilePicker\b'),
  'bottom sheet (hard to reach with the remote; use a Dialog)':
      RegExp(r'showModalBottomSheet|ApexBottomSheet'),
  'phone screen or widget used on the TV':
      RegExp(r'''import\s+['"][^'"]*\bmobile/'''),
};

Iterable<File> _tvFiles() => Directory('lib/tv')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/');

void main() {
  test('TV code uses nothing that needs touch or a file manager', () {
    final hits = <String>[];
    for (final f in _tvFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final rule in _touchOnly.entries) {
          if (rule.value.hasMatch(lines[i])) {
            hits.add('${_rel(f)}:${i + 1}: ${rule.key}');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('each TV widget class is defined in one file only', () {
    final where = <String, List<String>>{};
    final classDecl = RegExp(r'^class\s+(TV\w+)', multiLine: true);
    for (final f in _tvFiles()) {
      for (final m in classDecl.allMatches(f.readAsStringSync())) {
        where.putIfAbsent(m.group(1)!, () => []).add(_rel(f));
      }
    }
    final dupes = where.entries
        .where((e) => e.value.length > 1)
        .map((e) => '${e.key}: ${e.value.join(', ')}')
        .toList();
    expect(dupes, isEmpty,
        reason: 'Two copies drift apart; a fix in one is missing in the other:\n'
            '${dupes.join('\n')}');
  });
}
