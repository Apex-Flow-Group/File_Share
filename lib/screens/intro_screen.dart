import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/settings_service.dart';
import 'tour_screen.dart';

class IntroScreen extends StatefulWidget {
  final SettingsService settings;

  const IntroScreen({required this.settings, super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _buttonDraw;
  late Animation<double> _buttonFill;
  late Animation<double> _buttonTextFade;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.linear)),
    );

    _titleSlide = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.4, curve: Curves.easeOut)),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.4, curve: Curves.easeIn)),
    );

    _subtitleSlide = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6, curve: Curves.easeIn)),
    );

    _buttonDraw = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 0.7, curve: Curves.easeInOut)),
    );

    _buttonFill = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 0.85, curve: Curves.easeIn)),
    );

    _buttonTextFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.85, 1.0, curve: Curves.easeIn)),
    );

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TourScreen(settings: widget.settings),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isWideScreen = screenSize.width > 900;

    // Dynamic font sizes based on screen size
    final titleFontSize = isWideScreen ? 72.0 : (isSmallScreen ? screenSize.width * 0.12 : 56.0);
    final subtitleFontSize = isWideScreen ? 28.0 : (isSmallScreen ? screenSize.width * 0.045 : 20.0);
    final buttonWidth = isWideScreen ? 350.0 : (isSmallScreen ? 250.0 : 300.0);
    final buttonHeight = isWideScreen ? 64.0 : 56.0;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                _AnimatedBackground(progress: _backgroundAnimation.value),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWideScreen ? 900 : 600),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(isWideScreen ? 48 : 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),
                            Transform.translate(
                              offset: Offset(isArabic ? _titleSlide.value : -_titleSlide.value, 0),
                              child: Opacity(
                                opacity: _titleFade.value,
                                child: _ShinyText(
                                  text: l10n.appTitle,
                                  fontSize: titleFontSize,
                                  shimmerProgress: _shimmerAnimation.value,
                                ),
                              ),
                            ),
                            SizedBox(height: isWideScreen ? 24 : 16),
                            Transform.translate(
                              offset: Offset(isArabic ? _subtitleSlide.value : -_subtitleSlide.value, 0),
                              child: Opacity(
                                opacity: _subtitleFade.value,
                                child: _ShinyText(
                                  text: l10n.fastAndSecure,
                                  fontSize: subtitleFontSize,
                                  shimmerProgress: _shimmerAnimation.value,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _ComplexButton(
                              text: l10n.startTour,
                              drawProgress: _buttonDraw.value,
                              fillProgress: _buttonFill.value,
                              textOpacity: _buttonTextFade.value,
                              onPressed: _startApp,
                              width: buttonWidth,
                              height: buttonHeight,
                            ),
                            SizedBox(height: isWideScreen ? 48 : 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final double progress;

  const _AnimatedBackground({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(progress: progress),
      child: Container(),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double progress;

  _BackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF1A237E),
        Color(0xFF283593),
        Color(0xFF1A237E),
      ],
      stops: [
        0.0 + sin(progress * pi * 2) * 0.1,
        0.5 + cos(progress * pi * 2) * 0.1,
        1.0,
      ],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    for (int i = 0; i < 20; i++) {
      final x = (i * 50.0 + progress * 100) % size.width;
      final y = (i * 30.0 + sin(progress * pi + i) * 50) % size.height;
      final paint = Paint()
        ..color = const Color(0xFF6750A4).withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset(x, y), 30, paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => true;
}

class _ShinyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double shimmerProgress;

  const _ShinyText({
    required this.text,
    required this.fontSize,
    required this.shimmerProgress,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFF6750A4),
            Color(0xFF9575CD),
            Color(0xFFE1BEE7),
            Color(0xFF9575CD),
            Color(0xFF6750A4),
          ],
          stops: [
            max(0, shimmerProgress - 0.3),
            max(0, shimmerProgress - 0.1),
            shimmerProgress,
            min(1, shimmerProgress + 0.1),
            min(1, shimmerProgress + 0.3),
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _ComplexButton extends StatefulWidget {
  final String text;
  final double drawProgress;
  final double fillProgress;
  final double textOpacity;
  final VoidCallback onPressed;
  final double width;
  final double height;

  const _ComplexButton({
    required this.text,
    required this.drawProgress,
    required this.fillProgress,
    required this.textOpacity,
    required this.onPressed,
    this.width = 250,
    this.height = 56,
  });

  @override
  State<_ComplexButton> createState() => _ComplexButtonState();
}

class _ComplexButtonState extends State<_ComplexButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pulseController.forward().then((_) {
      _pulseController.reverse().then((_) {
        if (mounted) {
          widget.onPressed();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.textOpacity > 0.5 ? _handleTap : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + _pulseController.value * 0.1,
            child: CustomPaint(
              painter: _ButtonPainter(
                drawProgress: widget.drawProgress,
                fillProgress: widget.fillProgress,
                pulseProgress: _pulseController.value,
              ),
              child: Container(
                width: widget.width,
                height: widget.height,
                alignment: Alignment.center,
                child: Opacity(
                  opacity: widget.textOpacity,
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.width > 300 ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  final double drawProgress;
  final double fillProgress;
  final double pulseProgress;

  _ButtonPainter({
    required this.drawProgress,
    required this.fillProgress,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(28),
    );

    if (fillProgress > 0) {
      final fillPaint = Paint()
        ..color = const Color(0xFF6750A4).withValues(alpha: 0.3 * fillProgress)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, fillPaint);
    }

    if (drawProgress > 0) {
      final path = Path();
      final totalLength = (size.width + size.height) * 2;
      final currentLength = totalLength * drawProgress;

      path.addRRect(rect);

      final pathMetrics = path.computeMetrics().first;
      final extractPath = pathMetrics.extractPath(0, currentLength);

      final borderPaint = Paint()
        ..color = const Color(0xFF9575CD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(extractPath, borderPaint);
    }

    if (pulseProgress > 0) {
      final pulsePaint = Paint()
        ..color = const Color(0xFF9575CD).withValues(alpha: 0.3 * (1 - pulseProgress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + pulseProgress * 8;
      canvas.drawRRect(rect, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter oldDelegate) => true;
}
