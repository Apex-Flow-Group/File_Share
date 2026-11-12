import 'dart:io';

import 'package:apex_file_share/shared/apex_colors.dart';
import 'package:apex_file_share/shared/apex_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bars, the sidebars and the device card take their colours from the
/// theme's roles (owner decision): a number in one of them is a colour the
/// others do not follow.
const _themed = [
  'lib/mobile/widgets/home_nav_bar.dart',
  'lib/mobile/widgets/home_sidebar.dart',
  'lib/mobile/screens/home_screen.dart',
  'lib/tv/screens/tv_home_screen.dart',
  'lib/shared/device_card.dart',
  'lib/tv/widgets/tabs/tv_send_device_card.dart',
  'lib/shared/framed_capsule_input.dart',
];

/// One icon per action on every device (owner decision): named only in
/// lib/shared/apex_icons.dart.
final _actionIcons = RegExp(r'\bIcons\.(star_rounded|star_border_rounded|folder_shared_rounded|'
    r'block_rounded|expand_less_rounded|upload_file_rounded|send_rounded|send_outlined|'
    r'more_horiz_rounded|smartphone_outlined|folder_outlined|settings_outlined)\b');

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('the bars, sidebars and card name no colour of their own', () {
    final number = RegExp(r'Color\(0x|(?<![A-Za-z])Colors\.(?!transparent\b)');
    final found = <String>[];
    for (final path in _themed) {
      final lines = File(path).readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (number.hasMatch(line)) {
          found.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(found, isEmpty);
  });

  test('an action icon is named only in the icons table', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.endsWith('lib/shared/apex_icons.dart')) {
        continue;
      }
      for (final (i, line) in f.readAsLinesSync().indexed) {
        if (_actionIcons.hasMatch(line)) {
          found.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(found, isEmpty);
  });

  test('the device card is one file for the phone, the computer and the TV', () {
    final defines = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (f.readAsStringSync().contains('class DeviceCard ')) {
        defines.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(defines, ['lib/shared/device_card.dart']);
    // Both hosts draw it; neither keeps a card of its own.
    for (final host in [
      'lib/mobile/widgets/connection_widget.dart',
      'lib/tv/widgets/tabs/tv_send_device_card.dart',
    ]) {
      final src = File(host).readAsStringSync();
      expect(src, contains('DeviceCard('), reason: host);
      expect(src, isNot(contains('CircleAvatar')), reason: host);
      expect(src, isNot(contains('PopupMenuButton')), reason: host);
    }
  });

  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      final c = brightness == Brightness.dark ? ApexColors.dark : ApexColors.light;

      test('the theme carries the roles, its surfaces on the same steps', () {
        final theme = apexTheme(brightness);
        expect(theme.extension<ApexColors>(), same(c));
        expect(theme.scaffoldBackgroundColor, c.window);
        expect(theme.colorScheme.surface, c.window);
        expect(theme.colorScheme.surfaceContainer, c.panel);
        expect(theme.colorScheme.onSurface, c.text);
      });

      test('text reads 7:1 on what it sits on', () {
        for (final (fg, bg, what) in [
          (c.text, c.window, 'text on window'),
          (c.text, c.panel, 'text on panel'),
          (c.text, c.selected, 'text on selected'),
          (c.text, c.floating, 'text on the floating bar'),
          (c.text, c.floatingSelected, 'text on its selected tab'),
          (c.onCircle, c.circle, 'icon on circle'),
          (c.text, c.capsule, 'text in the message box'),
        ]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(7), reason: what);
        }
      });

      test('second lines and red text read 4.5:1', () {
        for (final (fg, bg, what) in [
          (c.muted, c.panel, 'muted on panel'),
          (c.muted, c.floating, 'muted on the floating bar'),
          (c.danger, c.circle, 'block in the menu'),
          (c.accent, c.panel, 'the unread count'),
        ]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: what);
        }
      });

      test('the focus ring and the online dot show 3:1', () {
        for (final (fg, bg, what) in [
          (c.accent, c.window, 'focus ring on window'),
          (c.accent, c.panel, 'focus ring on panel'),
          (c.online, c.panel, 'online dot'),
        ]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(3), reason: what);
        }
      });

      test('selected is a step lighter, not another colour', () {
        // A step off the panel in the surface's own direction.
        final up = brightness == Brightness.dark;
        bool lighter(Color a, Color b) =>
            up ? _luminance(a) > _luminance(b) : _luminance(a) < _luminance(b);
        expect(lighter(c.selected, c.panel), isTrue);
        expect(lighter(c.hover, c.panel), isTrue);
        expect(lighter(c.selected, c.hover), isTrue);
        final hsl = HSLColor.fromColor(c.selected);
        expect(hsl.saturation, lessThan(0.1), reason: 'a grey, not a colour');
      });
    });
  }
}
