@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic written in the code beside an `isAr` reached the screen without
/// the translation files: no English for it, or Arabic for English users
/// (desktop notifications), and outside what arabic-reviewer sees. Every
/// shown text comes from lib/l10n. Allowed: log lines, which the user does
/// not read, and «العربية», the language's own name in the language list.
void main() {
  test('no Arabic text is written in the code', () {
    final arabic = RegExp(r'[\u0600-\u06FF]');
    final literal = RegExp(r"'(?:[^'\\]|\\.)*'" r'''|"(?:[^"\\]|\\.)*"''');
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/generated/')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.trimLeft();
        // A log call may put its text on the next line.
        final logged = line.contains('ApexLogger') || (i > 0 && lines[i - 1].contains('ApexLogger'));
        if (code.startsWith('//') || logged) {
          continue;
        }
        for (final m in literal.allMatches(line)) {
          final text = m.group(0)!;
          if (arabic.hasMatch(text) && text != "'العربية'") {
            found.add('${f.path}:${i + 1}: $text');
          }
        }
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
