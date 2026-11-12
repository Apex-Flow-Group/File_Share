import 'package:flutter/material.dart';

import 'core/apex_core.dart';
import 'l10n/generated/app_localizations.dart';
import 'managers/permission_manager.dart';
import 'mobile/screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/splash_screen.dart';
import 'services/desktop_notification_service.dart';
import 'services/settings_service.dart';
import 'shared/apex_theme.dart';
import 'tv/screens/tv_home_screen.dart';
import 'tv/screens/tv_intro_screen.dart';
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
      theme: apexTheme(Brightness.light),
      darkTheme: apexTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: SplashScreen(
        onInit: _initAll,
        nextScreenBuilder: (s) => FileShareApp(settings: s),
      ),
    );
  }

  // No firewall rule from here: it opened the app on company (domain)
  // networks, was added on every launch and never removed. Windows asks the
  // user itself the first time the app listens.
  Future<SettingsService> _initAll() async {
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
          theme: apexTheme(Brightness.light),
          darkTheme: apexTheme(Brightness.dark),
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
