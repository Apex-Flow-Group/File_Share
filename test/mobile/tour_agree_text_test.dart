import 'dart:ui' show Locale;

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/screens/tour_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tour's agreement line promises permissions only where they are asked
/// (Android). On Windows and Linux none are, so it must not mention them.
void main() {
  for (final lang in ['ar', 'en']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    test('$lang: where permissions are asked, the line says so', () {
      expect(tourAgreeText(l10n, asksPermissions: true), l10n.tourAgree);
    });

    test('$lang: where none are asked, the line does not name them', () {
      final text = tourAgreeText(l10n, asksPermissions: false);
      expect(text, isNot(l10n.tourAgree));
      expect(text, isNot(contains(lang == 'ar' ? 'صلاحي' : 'ermission')));
    });
  }
}
