import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/apex_core.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/tv_home_screen.dart';
import 'services/settings_service.dart';
import 'utils/platform_detector.dart';
import 'widgets/transfer_progress_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Platform Detector
  await PlatformDetector.instance.initialize();
  
  // Initialize ApexCore
  await ApexCore.instance.initialize();
  
  final settings = SettingsService();
  await settings.loadSettings();
  runApp(FileShareApp(settings: settings));
}

class FileShareApp extends StatelessWidget {
  final SettingsService settings;

  const FileShareApp({required this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Apex Sender',
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          localeResolutionCallback: (locale, supportedLocales) {
            if (settings.locale != null) {
              return settings.locale;
            }
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale?.languageCode) {
                return supportedLocale;
              }
            }
            return supportedLocales.first;
          },
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6750A4),
              onPrimary: Color(0xFFFFFFFF),
              secondary: Color(0xFF00897B),
              onSecondary: Color(0xFFFFFFFF),
              surface: Color(0xFFFFFFFF),
              onSurface: Color(0xFF1C1B1F),
              outline: Color(0xFFCAC4D0),
              surfaceContainerHighest: Color(0xFFE7E0EC),
              onSurfaceVariant: Color(0xFF49454F),
            ),
            fontFamily: 'Cairo',
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFCAC4D0), width: 1),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFFCAC4D0),
              thickness: 1,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6750A4),
              onPrimary: Color(0xFFFFFFFF),
              secondary: Color(0xFF00897B),
              onSecondary: Color(0xFFFFFFFF),
              surface: Color(0xFF1C1B1F),
              onSurface: Color(0xFFE6E1E5),
              outline: Color(0xFF938F99),
              surfaceContainerHighest: Color(0xFF49454F),
              onSurfaceVariant: Color(0xFFCAC4D0),
            ),
            fontFamily: 'Cairo',
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFF938F99), width: 1),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFF938F99),
              thickness: 1,
            ),
          ),
          themeMode: settings.themeMode,
          home: TransferProgressOverlay(
            child: _buildHome(settings),
          ),
        );
      },
    );
  }

  Widget _buildHome(SettingsService settings) {
    // For TV, skip intro and use TV layout
    if (PlatformDetector.instance.isTV) {
      return TVHomeScreen(settings: settings);
    }
    
    // For mobile, use normal flow
    return settings.hasSeenIntro 
      ? HomeScreen(settings: settings)
      : IntroScreen(settings: settings);
  }
}
