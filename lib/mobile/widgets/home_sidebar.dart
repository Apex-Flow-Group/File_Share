import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Colour roles of the desktop sidebar (owner's reference): a framed panel a
/// step off the window, rows that light a step on hover and two on select.
class SidebarColors {
  const SidebarColors._({
    required this.panel,
    required this.border,
    required this.hover,
    required this.selected,
    required this.text,
    required this.muted,
  });

  final Color panel;
  final Color border;
  final Color hover;
  final Color selected;
  final Color text;

  /// Rows not selected, and the group line.
  final Color muted;

  static const _dark = SidebarColors._(
    panel: Color(0xFF1C1C1C),
    border: Color(0xFF2E2E2E),
    hover: Color(0xFF262626),
    selected: Color(0xFF2E2E2E),
    text: Color(0xFFF4F4F2),
    muted: Color(0xFFC8C8C4),
  );

  static const _light = SidebarColors._(
    panel: Color(0xFFF7F7F5),
    border: Color(0xFFE2E2DF),
    hover: Color(0xFFEDEDEA),
    selected: Color(0xFFE4E4E1),
    text: Color(0xFF1F1F1D),
    muted: Color(0xFF4A4A47),
  );

  static SidebarColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// One row of the sidebar: lit a step while the mouse is over it, and more
/// while [lit] (selected, or what it opened is open). [compact] leaves the
/// icon alone, its label in a tooltip.
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.lit,
    required this.onTap,
    required this.compact,
    this.spin,
  });

  final IconData icon;
  final String label;
  final bool lit;
  final VoidCallback onTap;
  final bool compact;
  final Animation<double>? spin;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = SidebarColors.of(context);
    final fg = widget.lit ? c.text : c.muted;
    Widget icon = Icon(widget.icon, size: 20, color: fg);
    final spin = widget.spin;
    if (spin != null) {
      icon = RotationTransition(turns: spin, child: icon);
    }
    Widget row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Durations.short2,
          curve: Easing.standard,
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 12),
          decoration: BoxDecoration(
            color: widget.lit
                ? c.selected
                : (_hover ? c.hover : c.hover.withValues(alpha: 0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.compact
              ? Center(child: icon)
              : Row(children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              widget.lit ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                        )),
                  ),
                ]),
        ),
      ),
    );
    if (widget.compact) {
      row = Tooltip(message: widget.label, child: row);
    }
    return Semantics(
      button: true,
      selected: widget.lit,
      label: widget.compact ? widget.label : null,
      child:
          Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: row),
    );
  }
}

/// عنصر القائمة الجانبية (Desktop)
class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => _SidebarRow(
        icon: icon,
        label: label,
        lit: selected,
        onTap: onTap,
        compact: compact,
      );
}

/// The desktop sidebar (owner's reference): a framed panel with a fold
/// button, the pages, then the tools at the foot. Folded, it is a column of
/// icons whose names show on hover.
class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    required this.isRunning,
    required this.currentIndex,
    required this.onSelect,
    required this.onRefresh,
    required this.onSettings,
    required this.onAbout,
    super.key,
  });

  final bool isRunning;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSettings;
  final Future<void> Function() onAbout;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SidebarColors.of(context);
    final folded = _compact;
    final status = widget.isRunning ? l10n.connected : l10n.notConnected;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.isRunning ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
    final pages = [
      (Icons.send_outlined, l10n.send),
      (Icons.smartphone_outlined, l10n.receive),
      (Icons.folder_outlined, l10n.files),
    ];
    return AnimatedContainer(
      duration: Durations.medium1,
      curve: Easing.standard,
      width: folded ? 68 : 232,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          // Its rows follow the width it has now, so none overflows while
          // the panel grows or shrinks.
          final compact = box.maxWidth < 150;
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── The fold button, then the name and whether it is on.
                Row(children: [
                  Tooltip(
                    message: folded ? l10n.sidebarExpand : l10n.sidebarCollapse,
                    child: _CircleButton(
                      icon: Icons.view_sidebar_outlined,
                      label: folded ? l10n.sidebarExpand : l10n.sidebarCollapse,
                      onTap: () => setState(() => _compact = !_compact),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Apex Transfer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: c.text)),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                Tooltip(
                  message: status,
                  child: Row(children: [
                    SizedBox(
                        width: compact ? 46 : 14, child: Center(child: dot)),
                    if (!compact) ...[
                      const SizedBox(width: 6),
                      Text(status,
                          style: TextStyle(fontSize: 12, color: c.muted)),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                for (final (i, (icon, label)) in pages.indexed)
                  SidebarItem(
                    icon: icon,
                    label: label,
                    selected: widget.currentIndex == i,
                    compact: compact,
                    onTap: () => widget.onSelect(i),
                  ),
                const Spacer(),
                Divider(height: 17, color: c.border),
                SidebarActionTile(
                    icon: Icons.restart_alt_rounded,
                    label: l10n.restartingSystem,
                    spinWhileBusy: true,
                    compact: compact,
                    onTap: widget.onRefresh),
                SidebarActionTile(
                    icon: Icons.settings_outlined,
                    label: l10n.settings,
                    compact: compact,
                    onTap: widget.onSettings),
                SidebarActionTile(
                    icon: Icons.info_outline_rounded,
                    label: l10n.about,
                    compact: compact,
                    onTap: widget.onAbout),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// The fold button: a filled circle a step off the panel (capsule-ui §1).
class _CircleButton extends StatefulWidget {
  const _CircleButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = SidebarColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Durations.short2,
            width: 46,
            height: 40,
            decoration: BoxDecoration(
              color: _hover ? c.selected : c.hover,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(widget.icon, size: 20, color: c.text),
          ),
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
  final bool compact;

  const SidebarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.spinWhileBusy = false,
    this.compact = false,
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
  Widget build(BuildContext context) => _SidebarRow(
        icon: widget.icon,
        label: widget.label,
        lit: _busy,
        onTap: _run,
        compact: widget.compact,
        spin: _spin,
      );
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
