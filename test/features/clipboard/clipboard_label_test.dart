import 'dart:io';

import 'package:apex_file_share/features/clipboard/ui/clipboard_label.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/services/clipboard_monitor_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copied text is often a password. Owner decision: its content is never
/// shown (not in the device card, not in the system notification), only
/// "text (N characters)"; and copying does not switch the app's tab.
void main() {
  const secret = 'P@ssw0rd-corp-2026';

  for (final locale in AppLocalizations.supportedLocales) {
    test('copied text shows its length, never its content (${locale.languageCode})', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      const item = ClipboardItem(paths: [], type: ClipboardItemType.text, text: secret);

      final label = clipboardLabel(l10n, item);

      expect(label, isNot(contains('P@ss')));
      expect(label, isNot(contains('corp')));
      expect(label, contains('${secret.length}'));
    });
  }

  test('in the device card, beside the type chip, text is named by its length alone', () async {
    final l10n = await AppLocalizations.delegate.load(AppLocalizations.supportedLocales.first);
    const item = ClipboardItem(paths: [], type: ClipboardItemType.text, text: secret);

    final label = clipboardLabel(l10n, item, typeShown: true);

    expect(label, isNot(contains('P@ss')));
    expect(label, contains('${secret.length}'));
    expect(label, isNot(clipboardLabel(l10n, item)));
  });

  test('several copied files are counted in the app language', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      const item = ClipboardItem(paths: ['/a/1.png', '/a/2.png', '/a/3.png'], type: ClipboardItemType.files);
      expect(clipboardLabel(l10n, item), l10n.clipboardFileCount(3));
      // In the card the chip already counts them: the label names the first.
      expect(clipboardLabel(l10n, item, typeShown: true), '1.png');
    }
  });

  test('a copied file shows its name', () async {
    final l10n = await AppLocalizations.delegate.load(AppLocalizations.supportedLocales.first);
    const item = ClipboardItem(paths: [r'C:\Users\a\Pictures\photo.png'], type: ClipboardItemType.image);

    expect(clipboardLabel(l10n, item), 'photo.png');
  });

  test('copying does not switch the app to the send tab', () {
    final code = File('lib/mobile/controllers/home_controller.dart').readAsStringSync();
    final listener = RegExp(r'ClipboardMonitorService\.instance\.stream\.listen\(([\s\S]*?)\n    \}\);')
        .firstMatch(code)
        ?.group(1);
    expect(listener, isNotNull, reason: 'The clipboard listener moved; update this test.');
    expect(listener, isNot(contains('_currentIndex')));
  });

  test('no screen reads the copied text to show it', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('clipboard_monitor_service.dart')) {
        continue;
      }
      if (RegExp(r'\.(textPreview|displayName)\b').hasMatch(f.readAsStringSync()) &&
          f.readAsStringSync().contains('ClipboardItem')) {
        hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
  });
}
