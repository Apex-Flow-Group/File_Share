import 'package:flutter/material.dart';

/// Animated button with border-draw + fill + pulse effects for intro/onboarding.
class IntroButton extends StatefulWidget {
  final String text;
  final double drawProgress;
  final double fillProgress;
  final double textOpacity;
  final VoidCallback onPressed;
  final double width;
  final double height;

  const IntroButton({
    required this.text,
    required this.drawProgress,
    required this.fillProgress,
    required this.textOpacity,
    required this.onPressed,
    this.width = 250,
    this.height = 56,
    super.key,
  });

  @override
  State<IntroButton> createState() => _IntroButtonState();
}

class _IntroButtonState extends State<IntroButton>
    with SingleTickerProviderStateMixin {
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
        ..color =
            const Color(0xFF9575CD).withValues(alpha: 0.3 * (1 - pulseProgress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + pulseProgress * 8;
      canvas.drawRRect(rect, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter oldDelegate) => true;
}
