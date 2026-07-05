import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable TV-friendly focusable dialog option button.
class TVDialogOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool autofocus;
  final VoidCallback onTap;

  const TVDialogOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.autofocus,
    required this.onTap,
    super.key,
  });

  @override
  State<TVDialogOption> createState() => _TVDialogOptionState();
}

class _TVDialogOptionState extends State<TVDialogOption> {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasFocus
                  ? widget.color.withValues(alpha: 0.15)
                  : widget.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: hasFocus
                  ? Border.all(color: widget.color, width: 2)
                  : Border.all(color: widget.color.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(width: 12),
              Text(widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                  )),
            ]),
          ),
        );
      }),
    );
  }
}

/// Reusable TV-friendly focusable action button (e.g., for confirm dialogs).
class TVDialogButton extends StatefulWidget {
  final String label;
  final Color color;
  final bool autofocus;
  final VoidCallback onTap;

  const TVDialogButton({
    required this.label,
    required this.color,
    required this.autofocus,
    required this.onTap,
    super.key,
  });

  @override
  State<TVDialogButton> createState() => _TVDialogButtonState();
}

class _TVDialogButtonState extends State<TVDialogButton> {
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: hasFocus
                  ? widget.color.withValues(alpha: 0.15)
                  : widget.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: hasFocus
                  ? Border.all(color: widget.color, width: 2)
                  : Border.all(color: widget.color.withValues(alpha: 0.2)),
            ),
            child: Center(
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

/// TV-friendly focusable text button with external FocusNode.
class TVFocusableButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Color color;
  final String label;

  const TVFocusableButton({
    required this.focusNode,
    required this.onTap,
    required this.color,
    required this.label,
    super.key,
  });

  @override
  State<TVFocusableButton> createState() => _TVFocusableButtonState2();
}

class _TVFocusableButtonState2 extends State<TVFocusableButton> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: hasFocus ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.color.withValues(alpha: hasFocus ? 0.8 : 0.3),
                width: hasFocus ? 2 : 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                color: widget.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// TV-friendly focusable icon button with external FocusNode.
class TVFocusableIconButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onTap;

  const TVFocusableIconButton({
    required this.focusNode,
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  State<TVFocusableIconButton> createState() => _TVFocusableIconButtonState2();
}

class _TVFocusableIconButtonState2 extends State<TVFocusableIconButton> {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: widget.focusNode,
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
              color:
                  hasFocus ? color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: hasFocus ? Border.all(color: color, width: 2) : null,
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: hasFocus
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }
}
