import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// زر قابل للتركيز بالريموت — يُستخدم في جميع dialogs و tiles الـ TV
class TVFocusableButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool autofocus;
  final VoidCallback onTap;
  final bool filled;

  const TVFocusableButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.autofocus = false,
    this.filled = false,
    super.key,
  });

  @override
  State<TVFocusableButton> createState() => _TVFocusableButtonState();
}

class _TVFocusableButtonState extends State<TVFocusableButton> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: widget.icon != null ? 16 : 12,
              vertical: widget.icon != null ? 14 : 12,
            ),
            decoration: BoxDecoration(
              color: hasFocus
                  ? widget.color.withValues(alpha: 0.15)
                  : widget.color.withValues(alpha: widget.filled ? 0.06 : 0.05),
              borderRadius:
                  BorderRadius.circular(widget.icon != null ? 14 : 12),
              border: hasFocus
                  ? Border.all(color: widget.color, width: 2)
                  : Border.all(
                      color: widget.color
                          .withValues(alpha: widget.filled ? 0.2 : 0.15)),
            ),
            child: widget.icon != null
                ? Row(children: [
                    Icon(widget.icon, color: widget.color, size: 20),
                    const SizedBox(width: 12),
                    Text(widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.color,
                        )),
                  ])
                : Center(
                    child: Text(widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.color,
                        )),
                  ),
          ),
        );
      }),
    );
  }
}

/// زر أيقونة قابل للتركيز بالريموت (مثل refresh)
class TVFocusableIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const TVFocusableIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  @override
  State<TVFocusableIconButton> createState() => _TVFocusableIconButtonState();
}

class _TVFocusableIconButtonState extends State<TVFocusableIconButton> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: hasFocus ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  hasFocus ? Border.all(color: widget.color, width: 2) : null,
            ),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
        );
      }),
    );
  }
}
