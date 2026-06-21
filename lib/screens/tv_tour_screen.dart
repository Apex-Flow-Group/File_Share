import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../managers/permission_manager.dart';
import '../services/settings_service.dart';
import 'tv_home_screen.dart';

class TVTourScreen extends StatefulWidget {
  final SettingsService settings;
  const TVTourScreen({required this.settings, super.key});

  @override
  State<TVTourScreen> createState() => _TVTourScreenState();
}

class _TVTourScreenState extends State<TVTourScreen> {
  bool _agreed = false;
  final _scrollCtrl = ScrollController();

  // Focus nodes بالترتيب: scroll area → checkbox → button
  final FocusNode _scrollFocus  = FocusNode(debugLabel: 'tour-scroll');
  final FocusNode _checkFocus   = FocusNode(debugLabel: 'tour-check');
  final FocusNode _startFocus   = FocusNode(debugLabel: 'tour-start');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _scrollFocus.dispose();
    _checkFocus.dispose();
    _startFocus.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_agreed) return;
    await PermissionManager.requestAll();
    await widget.settings.markIntroAsSeen();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TVHomeScreen(settings: widget.settings),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = Theme.of(context).colorScheme.primary;
    final isAr   = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          // ─── Left panel: features list ──────────────────────────────
          Expanded(
            flex: 5,
            child: Focus(
              focusNode: _scrollFocus,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _scrollCtrl.animateTo(
                    (_scrollCtrl.offset + 120).clamp(
                        0.0, _scrollCtrl.position.maxScrollExtent),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _scrollCtrl.animateTo(
                    (_scrollCtrl.offset - 120).clamp(
                        0.0, _scrollCtrl.position.maxScrollExtent),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                  return KeyEventResult.handled;
                }
                // انتقل للـ checkbox بالسهم الجانبي
                final toRight = isAr
                    ? LogicalKeyboardKey.arrowLeft
                    : LogicalKeyboardKey.arrowRight;
                if (event.logicalKey == toRight) {
                  _checkFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(builder: (ctx) {
                final hasFocus = Focus.of(ctx).hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: hasFocus
                        ? Border.all(color: color.withValues(alpha: 0.4), width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        // Header
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/images/ico.png',
                                width: 52, height: 52, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 14),
                          Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(l10n.appTitle,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            Text(l10n.fastAndSecure,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ]),
                        ]),
                        const SizedBox(height: 24),
                        // Features
                        ..._features(l10n, isAr).map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TVFeatureCard(feature: f, isDark: isDark),
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // ─── Right panel: agree + start ─────────────────────────────
          Container(
            width: 300,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 48, color: color.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'قبل البدء' : 'Before You Start',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'مرر المميزات للأعلى والأسفل\nثم وافق على الشروط للمتابعة'
                      : 'Scroll through the features\nthen agree to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Checkbox
                Focus(
                  focusNode: _checkFocus,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      setState(() => _agreed = !_agreed);
                      if (_agreed) _startFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _startFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _scrollFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _agreed = !_agreed);
                        if (_agreed) _startFocus.requestFocus();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _agreed
                              ? color.withValues(alpha: 0.12)
                              : hasFocus
                                  ? color.withValues(alpha: 0.06)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasFocus || _agreed
                                ? color.withValues(alpha: hasFocus ? 0.7 : 0.3)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: hasFocus ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _agreed ? color : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _agreed ? color : Colors.grey.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: _agreed
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAr ? 'أوافق على الشروط' : 'I agree to terms',
                              style: TextStyle(
                                fontSize: 13,
                                color: _agreed || hasFocus ? color : null,
                                fontWeight: _agreed
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // Start Button
                Focus(
                  focusNode: _startFocus,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      _start();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _checkFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: _start,
                      child: AnimatedOpacity(
                        opacity: _agreed ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 250),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: hasFocus && _agreed ? color : color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: hasFocus
                                ? Border.all(color: color, width: 2)
                                : null,
                            boxShadow: hasFocus && _agreed
                                ? [BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                  )]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rocket_launch_rounded,
                                size: 18,
                                color: hasFocus && _agreed
                                    ? Colors.white
                                    : color,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.finish,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: hasFocus && _agreed
                                      ? Colors.white
                                      : color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  List<_Feature> _features(AppLocalizations l10n, bool isAr) => [
        _Feature(Icons.bolt_rounded, const Color(0xFFFF9500),
            l10n.feature1Title, l10n.feature1Desc),
        _Feature(Icons.wifi_off_rounded, const Color(0xFF34C759),
            l10n.feature2Title, l10n.feature2Desc),
        _Feature(Icons.lock_rounded, const Color(0xFF5856D6),
            l10n.feature3Title, l10n.feature3Desc),
        _Feature(Icons.sensors_rounded, const Color(0xFF007AFF),
            'Nearby + WiFi',
            isAr ? 'اكتشاف تلقائي سريع' : 'Fast auto-discovery'),
        _Feature(Icons.phone_android_rounded, const Color(0xFFFF2D55),
            'APK Sharing',
            isAr ? 'شارك تطبيقاتك المثبتة' : 'Share your installed apps'),
        _Feature(Icons.devices_rounded, const Color(0xFF32ADE6),
            'Multi-platform',
            isAr ? 'هاتف، تابلت، كمبيوتر' : 'Phone, tablet & desktop'),
      ];
}

// ─── Feature Card ──────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _Feature(this.icon, this.color, this.title, this.desc);
}

class _TVFeatureCard extends StatelessWidget {
  final _Feature feature;
  final bool isDark;
  const _TVFeatureCard({required this.feature, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [feature.color, feature.color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(feature.icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(feature.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 3),
            Text(feature.desc,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.3,
                )),
          ]),
        ),
      ]),
    );
  }
}
