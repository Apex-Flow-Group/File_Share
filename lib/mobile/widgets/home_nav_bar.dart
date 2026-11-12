import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/apex_colors.dart';
import '../../shared/apex_icons.dart';

/// شريط التنقل السفلي العائم (Mobile)
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isRunning;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAboutTap;
  final VoidCallback onRestartTap;

  const FloatingNavBar({
    required this.currentIndex,
    required this.isRunning,
    required this.onTap,
    required this.onSettingsTap,
    required this.onAboutTap,
    required this.onRestartTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = ApexColors.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                // Floats over the cards, so a step above them (capsule-ui §2).
                color: c.floating.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: c.panelBorder),
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: ApexIcons.sendPage,
                    label: l10n.send,
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: ApexIcons.receivePage,
                    label: l10n.receive,
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: ApexIcons.filesPage,
                    label: l10n.files,
                    selected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: c.panelBorder,
                  ),
                  // More menu
                  _MoreButton(
                    isRunning: isRunning,
                    onSettingsTap: onSettingsTap,
                    onAboutTap: onAboutTap,
                    onRestartTap: onRestartTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
    // Selected is a lighter surface, as in the sidebar, not a colour.
    final color = selected ? c.text : c.muted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: Durations.short2,
                curve: Easing.standard,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? c.floatingSelected
                      : c.floatingSelected.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── More Button with Overlay Menu ────────────────────────────────────────────

class _MoreButton extends StatefulWidget {
  final bool isRunning;
  final VoidCallback onSettingsTap;
  final VoidCallback onAboutTap;
  final VoidCallback onRestartTap;

  const _MoreButton({
    required this.isRunning,
    required this.onSettingsTap,
    required this.onAboutTap,
    required this.onRestartTap,
  });

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final l10n = AppLocalizations.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final btnPos = renderBox.localToGlobal(Offset.zero);
    final btnSize = renderBox.size;

    _overlay = OverlayEntry(
      builder: (_) => _MenuOverlay(
        anchorPos: btnPos,
        anchorSize: btnSize,
        scaleAnim: _scaleAnim,
        fadeAnim: _fadeAnim,
        items: [
          _MenuItem(
            icon: ApexIcons.findDevices,
            label: l10n.findDevices,
            onTap: () {
              _close();
              widget.onRestartTap();
            },
          ),
          _MenuItem(
            icon: ApexIcons.settings,
            label: l10n.settings,
            onTap: () {
              _close();
              widget.onSettingsTap();
            },
          ),
          _MenuItem(
            icon: ApexIcons.about,
            label: l10n.about,
            onTap: () {
              _close();
              widget.onAboutTap();
            },
          ),
        ],
        onDismiss: _close,
      ),
    );

    Overlay.of(context).insert(_overlay!);
    setState(() {});
    _controller.forward(from: 0);
  }

  Future<void> _close() async {
    await _controller.reverse();
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: _overlay == null ? l10n.moreOptions : l10n.closeOptions,
      child: GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ⋮ turns into ✕ while its menu is open (capsule-ui §4).
            Icon(_overlay == null ? ApexIcons.menu : ApexIcons.close,
                color: ApexColors.of(context).muted),
            if (widget.isRunning)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: ApexColors.of(context).online,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Menu Item & Overlay ──────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});
}

class _MenuOverlay extends StatelessWidget {
  final Offset anchorPos;
  final Size anchorSize;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final List<_MenuItem> items;
  final VoidCallback onDismiss;

  const _MenuOverlay({
    required this.anchorPos,
    required this.anchorSize,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.items,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
    const menuWidth = 220.0;
    const itemHeight = 52.0;
    final menuHeight = items.length * itemHeight + 16;
    final left = (anchorPos.dx + anchorSize.width / 2 - menuWidth / 2)
        .clamp(12.0, MediaQuery.of(context).size.width - menuWidth - 12);
    final top = anchorPos.dy - menuHeight - 12;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: FadeTransition(
            opacity: fadeAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.floating,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.panelBorder),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: c.panelBorder,
                            ),
                          InkWell(
                            onTap: item.onTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(children: [
                                Icon(item.icon,
                                    size: 20,
                                    color: c.text),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: c.text,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
