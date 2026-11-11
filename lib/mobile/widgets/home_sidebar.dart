import 'dart:async';

import 'package:flutter/material.dart';

/// عنصر القائمة الجانبية (Desktop)
class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: isDark ? 0.2 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? color
                    : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? color
                      : (isDark ? Colors.white70 : Colors.black54),
                )),
          ]),
        ),
      ),
    );
  }
}

/// زر الإجراء في القائمة الجانبية (Desktop)
/// Lit from the press until what it started ends (a bottom sheet closes, a
/// refresh finishes); with [spinWhileBusy] the icon turns meanwhile.
class SidebarActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool spinWhileBusy;

  const SidebarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.spinWhileBusy = false,
    super.key,
  });

  @override
  State<SidebarActionTile> createState() => _SidebarActionTileState();
}

class _SidebarActionTileState extends State<SidebarActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: Durations.extralong2);
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    if (widget.spinWhileBusy) {
      unawaited(_spin.repeat());
    }
    try {
      await widget.onTap();
    } finally {
      if (widget.spinWhileBusy && mounted) {
        // Finish the turn under way so the icon ends upright.
        await _spin.forward();
        if (mounted) {
          _spin.value = 0;
        }
      }
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _busy
        ? scheme.onSurface
        : (isDark ? Colors.white60 : Colors.black45);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AnimatedContainer(
        duration: Durations.short4,
        curve: Easing.standard,
        decoration: BoxDecoration(
          color: _busy ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: _run,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              RotationTransition(
                turns: _spin,
                child: Icon(widget.icon, size: 18, color: fg),
              ),
              const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(fontSize: 13, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// زر أيقونة في Navigation Rail (Tablet)
class RailIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
