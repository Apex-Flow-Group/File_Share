import 'dart:io';

import 'package:flutter/material.dart';

import 'core/apex_core.dart';
import 'l10n/generated/app_localizations.dart';
import 'managers/permission_manager.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_intro_screen.dart';
import 'services/desktop_notification_service.dart';
import 'services/settings_service.dart';
import 'utils/platform_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp فوراً بدون أي await — السبلاش تظهر من أول فريم
  runApp(const _BootApp());
}

// ─── Boot App — يعرض السبلاش فوراً بالسمة الصحيحة ────────────────────────────

class _BootApp extends StatelessWidget {
  const _BootApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: SplashScreen(
        onInit: _initAll,
        nextScreenBuilder: (s) => FileShareApp(settings: s),
      ),
    );
  }

  Future<SettingsService> _initAll() async {
    if (Platform.isWindows) {
      try {
        final exe = Platform.resolvedExecutable;
        await Process.run('netsh', [
          'advfirewall', 'firewall', 'add', 'rule',
          'name=ApexFileShare', 'dir=in', 'action=allow',
          'program=$exe', 'enable=yes', 'profile=private,domain',
        ]);
      } catch (_) {}
    }
    await PlatformDetector.instance.initialize();
    await ApexCore.instance.initialize();
    await DesktopNotificationService.instance.initialize();
    // نعيد تحميل settings لتمرير instance جديدة لـ FileShareApp
    final s = SettingsService();
    await s.loadSettings();
    return s;
  }
}

// ─── Main App ─────────────────────────────────────────────────────────────────

class FileShareApp extends StatelessWidget {
  final SettingsService settings;
  const FileShareApp({required this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Apex File Share',
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          localeResolutionCallback: (locale, supportedLocales) {
            if (settings.locale != null) {
              return settings.locale;
            }
            for (final s in supportedLocales) {
              if (s.languageCode == locale?.languageCode) {
                return s;
              }
            }
            return supportedLocales.first;
          },
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: _buildHome(settings),
        );
      },
    );
  }

  Widget _buildHome(SettingsService settings) {
    if (PlatformDetector.instance.isTV) {
      return settings.hasSeenIntro
          ? _PermissionGate(child: TVHomeScreen(settings: settings))
          : TVIntroScreen(settings: settings);
    }
    return settings.hasSeenIntro
        ? _PermissionGate(child: HomeScreen(settings: settings))
        : IntroScreen(settings: settings);
  }
}

// ─── Permission Gate ──────────────────────────────────────────────────────────

class _PermissionGate extends StatefulWidget {
  final Widget child;
  const _PermissionGate({required this.child});

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    PermissionManager.requestAll().then((_) {
      if (mounted) {
        setState(() => _done = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}

// ─── Theme builder ────────────────────────────────────────────────────────────

ThemeData _buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: isLight
        ? const ColorScheme.light(
            primary: Color(0xFF6750A4),
            onPrimary: Color(0xFFFFFFFF),
            secondary: Color(0xFF00897B),
            onSecondary: Color(0xFFFFFFFF),
            surface: Color(0xFFFFFFFF),
            onSurface: Color(0xFF1C1B1F),
            outline: Color(0xFFCAC4D0),
            surfaceContainerHighest: Color(0xFFE7E0EC),
            onSurfaceVariant: Color(0xFF49454F),
          )
        : const ColorScheme.dark(
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
