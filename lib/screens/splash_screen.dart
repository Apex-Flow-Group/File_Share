import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../utils/platform_detector.dart';

class SplashScreen extends StatefulWidget {
  final Future<SettingsService> Function() onInit;
  final Widget Function(SettingsService) nextScreenBuilder;

  const SplashScreen({
    required this.onInit,
    required this.nextScreenBuilder,
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack),
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // الانتقال فور انتهاء الـ init — لا انتظار إضافي
    widget.onInit().then((settings) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.nextScreenBuilder(settings),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final isTV    = PlatformDetector.instance.isTV;
    const primary = Color(0xFF6750A4);
    final iconSize = isTV ? 88.0 : 76.0;
    final radius   = isTV ? 22.0 : 18.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F3FF),
      body: Stack(children: [

        // خلفية gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  primary.withValues(alpha: isDark ? 0.18 : 0.11),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_enterCtrl, _pulseCtrl]),
            builder: (_, __) => FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // أيقونة + glow
                    SizedBox(
                      width: iconSize + 44,
                      height: iconSize + 44,
                      child: Stack(alignment: Alignment.center, children: [

                        // outer glow
                        Transform.scale(
                          scale: _pulseScale.value * 1.3,
                          child: Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary.withValues(
                                  alpha: _pulseOpacity.value * 0.2),
                            ),
                          ),
                        ),

                        // inner glow
                        Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: iconSize + 12,
                            height: iconSize + 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary.withValues(
                                  alpha: _pulseOpacity.value * 0.15),
                            ),
                          ),
                        ),

                        // الأيقونة
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.38),
                                blurRadius: 24,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: Image.asset(
                              'assets/images/ico.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ]),
                    ),

                    SizedBox(height: isTV ? 18 : 14),

                    Text(
                      'Apex Transfer',
                      style: TextStyle(
                        fontSize: isTV ? 24 : 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1C1B1F),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Fast · Secure · Offline',
                      style: TextStyle(
                        fontSize: isTV ? 12 : 11,
                        letterSpacing: 1.4,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.32)
                            : Colors.black.withValues(alpha: 0.28),
                      ),
                    ),

                    SizedBox(height: isTV ? 36 : 28),

                    // loading indicator بسيط
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
