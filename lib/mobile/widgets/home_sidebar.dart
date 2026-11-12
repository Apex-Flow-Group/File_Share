import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/apex_colors.dart';
import '../../shared/apex_icons.dart';

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
    final c = ApexColors.of(context);
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
    final c = ApexColors.of(context);
    final folded = _compact;
    final status = widget.isRunning ? l10n.connected : l10n.notConnected;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.isRunning ? c.online : c.muted,
        shape: BoxShape.circle,
      ),
    );
    final pages = [
      (ApexIcons.sendPage, l10n.send),
      (ApexIcons.receivePage, l10n.receive),
      (ApexIcons.filesPage, l10n.files),
    ];
    return AnimatedContainer(
      duration: Durations.medium1,
      curve: Easing.standard,
      width: folded ? 68 : 232,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.panelBorder),
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
                Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Tooltip(
                        message:
                            folded ? l10n.sidebarExpand : l10n.sidebarCollapse,
                        child: _CircleButton(
                          folded: folded,
                          label: folded
                              ? l10n.sidebarExpand
                              : l10n.sidebarCollapse,
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
                Divider(height: 17, color: c.panelBorder),
                SidebarActionTile(
                    icon: ApexIcons.findDevices,
                    label: l10n.findDevices,
                    spinWhileBusy: true,
                    compact: compact,
                    onTap: widget.onRefresh),
                SidebarActionTile(
                    icon: ApexIcons.settings,
                    label: l10n.settings,
                    compact: compact,
                    onTap: widget.onSettings),
                SidebarActionTile(
                    icon: ApexIcons.about,
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

/// The fold button: a filled circle a step off the panel (capsule-ui §1),
/// with the owner's panel icon.
class _CircleButton extends StatefulWidget {
  const _CircleButton(
      {required this.folded, required this.label, required this.onTap});

  final bool folded;
  final String label;
  final VoidCallback onTap;

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hover ? c.selected : c.hover,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CustomPaint(
                size: const Size.square(18),
                painter: _PanelIconPainter(
                  color: c.text,
                  // The sidebar is on the reading side: the right in Arabic.
                  panelRight: Directionality.of(context) == TextDirection.rtl,
                  folded: widget.folded,
                ),
              ),
            ),
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

/// The owner's fold icon, which Material does not have: a framed panel with
/// a bar on the sidebar's side and an arrow towards it to fold, away from it
/// to open.
class _PanelIconPainter extends CustomPainter {
  const _PanelIconPainter(
      {required this.color, required this.panelRight, required this.folded});

  final Color color;
  final bool panelRight;
  final bool folded;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inset = pen.strokeWidth / 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(inset, inset, s - inset, s - inset),
            Radius.circular(s * 0.22)),
        pen);
    final bar = panelRight ? s * 0.68 : s * 0.32;
    canvas.drawLine(Offset(bar, inset), Offset(bar, s - inset), pen);
    // The arrow sits in the wide part; it points at the bar to fold.
    final towardBar = !folded;
    final pointsRight = panelRight == towardBar;
    final mid = panelRight ? s * 0.36 : s * 0.64;
    final half = s * 0.13;
    final tip = pointsRight ? mid + half / 1.4 : mid - half / 1.4;
    final back = pointsRight ? mid - half / 1.4 : mid + half / 1.4;
    canvas.drawPath(
        Path()
          ..moveTo(back, s / 2 - half)
          ..lineTo(tip, s / 2)
          ..lineTo(back, s / 2 + half),
        pen);
  }

  @override
  bool shouldRepaint(_PanelIconPainter old) =>
      old.color != color ||
      old.panelRight != panelRight ||
      old.folded != folded;
}

/// The tablet's rail, and a phone's held sideways: its pages, then the
/// tools at the foot, in the sidebars' roles.
class TabletRail extends StatelessWidget {
  const TabletRail({
    required this.currentIndex,
    required this.isRunning,
    required this.onSelect,
    required this.onRefresh,
    required this.onSettings,
    required this.onAbout,
    super.key,
  });

  final int currentIndex;
  final bool isRunning;
  final ValueChanged<int> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = ApexColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: BorderDirectional(end: BorderSide(color: c.panelBorder)),
      ),
      // With the keyboard up a phone held sideways has less height than the
      // pages and tools: the rail scrolls then, and fills the height otherwise.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: currentIndex < 3 ? currentIndex : 0,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                backgroundColor: c.panel.withValues(alpha: 0),
                // As the sidebars: selected is a lighter surface, not a colour.
                indicatorColor: c.selected,
                selectedIconTheme: IconThemeData(color: c.text),
                unselectedIconTheme: IconThemeData(color: c.muted),
                selectedLabelTextStyle: TextStyle(color: c.text, fontWeight: FontWeight.w600),
                unselectedLabelTextStyle: TextStyle(color: c.muted),
                destinations: [
                  NavigationRailDestination(icon: const Icon(ApexIcons.sendPage), label: Text(l10n.send)),
                  NavigationRailDestination(icon: const Icon(ApexIcons.receivePage), label: Text(l10n.receive)),
                  NavigationRailDestination(icon: const Icon(ApexIcons.filesPage), label: Text(l10n.files)),
                ],
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        RailIconButton(icon: ApexIcons.findDevices, tooltip: l10n.findDevices, onTap: onRefresh),
                        const SizedBox(height: 8),
                        RailIconButton(icon: ApexIcons.settings, tooltip: l10n.settings, onTap: onSettings),
                        const SizedBox(height: 8),
                        RailIconButton(icon: ApexIcons.about, tooltip: l10n.about, onTap: onAbout),
                        const SizedBox(height: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isRunning ? c.online : c.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
