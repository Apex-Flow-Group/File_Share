import 'package:flutter/material.dart';

import 'apex_colors.dart';

/// The app's theme, light and dark, built on [ApexColors].
ThemeData apexTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final c = isLight ? ApexColors.light : ApexColors.dark;
  return ThemeData(
    useMaterial3: true,
    extensions: [c],
    scaffoldBackgroundColor: c.window,
    // The surfaces are the roles' steps, so Material's own widgets (dialogs,
    // menus, sheets) sit on the same greys as the bars and cards.
    colorScheme: (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      primary: const Color(0xFF6750A4),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF00897B),
      onSecondary: const Color(0xFFFFFFFF),
      error: c.danger,
      surface: c.window,
      onSurface: c.text,
      surfaceContainer: c.panel,
      surfaceContainerHigh: c.hover,
      surfaceContainerHighest: c.circle,
      onSurfaceVariant: c.muted,
      outline: isLight ? const Color(0xFFCAC4D0) : const Color(0xFF938F99),
    ),
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: isLight ? const Color(0xFFCAC4D0) : const Color(0xFF938F99),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isLight ? const Color(0xFFCAC4D0) : const Color(0xFF938F99),
      thickness: 1,
    ),
  );
}
