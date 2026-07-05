import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';

// ─── Public entry point ───────────────────────────────────────────────────────
// استدعِ هذه الدالة من tv_home_screen لإظهار الـ panel

void showTVDetailsPanel(BuildContext context, SettingsService settings) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'panel',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _TVDetailsPanel(settings: settings),
    transitionBuilder: (ctx, anim, _, child) {
      final isRtl = Directionality.of(ctx) == TextDirection.rtl;
      final slide = Tween<Offset>(
        begin: Offset(isRtl ? -1 : 1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}

// ─── Panel widget ─────────────────────────────────────────────────────────────

class _TVDetailsPanel extends StatefulWidget {
  final SettingsService settings;
  const _TVDetailsPanel({required this.settings});

  @override
  State<_TVDetailsPanel> createState() => _TVDetailsPanelState();
}

class _TVDetailsPanelState extends State<_TVDetailsPanel> {
  // focus nodes للتنقل بالريموت
  final FocusNode _languageFocus = FocusNode(debugLabel: 'lang');
  final FocusNode _themeFocus = FocusNode(debugLabel: 'theme');
  final FocusNode _permissionFocus = FocusNode(debugLabel: 'perm');
  final FocusNode _closeFocus = FocusNode(debugLabel: 'close');

  late final List<FocusNode> _allNodes;

  @override
  void initState() {
    super.initState();
    _allNodes = [_languageFocus, _themeFocus, _permissionFocus, _closeFocus];
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _languageFocus.requestFocus());
  }

  @override
  void dispose() {
    for (final n in _allNodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleNavKey(FocusNode current, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final closeKey =
        isRtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;

    final idx = _allNodes.indexOf(current);

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (idx < _allNodes.length - 1) {
        _allNodes[idx + 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        _allNodes[idx - 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    // السهم للخارج يغلق الـ panel
    if (event.logicalKey == closeKey) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    // السهم للداخل — محجوز، لا يخرج
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenW = MediaQuery.of(context).size.width;
    final panelW = (screenW * 0.38).clamp(320.0, 480.0);

    return Align(
      alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelW,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: isRtl ? const Offset(8, 0) : const Offset(-8, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelHeader(context, l10n, isDark, color),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionLabel(context, l10n.appearance),
                        const SizedBox(height: 6),
                        _buildCard(context, isDark, [
                          _PanelItem(
                            focusNode: _languageFocus,
                            icon: Icons.language_rounded,
                            iconColor: const Color(0xFF007AFF),
                            title: l10n.language,
                            subtitle: _langName(
                                widget.settings.locale?.languageCode, l10n),
                            onTap: () => _pickLanguage(context, l10n),
                            onKey: (e) => _handleNavKey(_languageFocus, e),
                          ),
                          _PanelItem(
                            focusNode: _themeFocus,
                            icon: Icons.contrast_rounded,
                            iconColor: const Color(0xFF5856D6),
                            title: l10n.theme,
                            subtitle:
                                _themeName(widget.settings.themeMode, l10n),
                            onTap: () => _pickTheme(context, l10n),
                            onKey: (e) => _handleNavKey(_themeFocus, e),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _sectionLabel(context, l10n.permissions),
                        const SizedBox(height: 6),
                        _buildCard(context, isDark, [
                          _PanelItem(
                            focusNode: _permissionFocus,
                            icon: Icons.security_rounded,
                            iconColor: const Color(0xFF34C759),
                            title: l10n.appPermissions,
                            subtitle: l10n.managePermissions,
                            onTap: () => _managePermissions(context, l10n),
                            onKey: (e) => _handleNavKey(_permissionFocus, e),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        // زر إغلاق
                        _CloseButton(
                          focusNode: _closeFocus,
                          label: l10n.close,
                          onTap: () => Navigator.of(context).pop(),
                          onKey: (e) => _handleNavKey(_closeFocus, e),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildPanelHeader(
      BuildContext context, AppLocalizations l10n, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.settings_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Text(l10n.settings,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            )),
      ]),
    );
  }

  // ─── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, bool isDark, List<_PanelItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 52,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              _buildItemTile(context, item, isDark,
                  isFirst: i == 0, isLast: i == items.length - 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, _PanelItem item, bool isDark,
      {required bool isFirst, required bool isLast}) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: item.focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          item.onTap();
          return KeyEventResult.handled;
        }
        return item.onKey(event);
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        final radius = BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(16) : Radius.zero,
          topRight: isFirst ? const Radius.circular(16) : Radius.zero,
          bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
        );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: hasFocus ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: radius,
            border: hasFocus
                ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
                : null,
          ),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: item.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                    if (item.subtitle != null)
                      Text(item.subtitle!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                  ],
                )),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5)),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _langName(String? code, AppLocalizations l10n) {
    if (code == null) {
      return l10n.system;
    }
    return code == 'ar' ? 'العربية' : 'English';
  }

  String _themeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.light;
      case ThemeMode.dark:
        return l10n.dark;
      default:
        return l10n.system;
    }
  }

  // ─── Pickers ───────────────────────────────────────────────────────────────

  void _pickLanguage(BuildContext context, AppLocalizations l10n) {
    _showTVPicker(
      context: context,
      title: l10n.selectLanguage,
      items: [
        _PickItem(
            label: l10n.system, value: null, icon: Icons.phone_android_rounded),
        const _PickItem(
            label: 'العربية', value: 'ar', icon: Icons.translate_rounded),
        const _PickItem(
            label: 'English', value: 'en', icon: Icons.translate_rounded),
      ],
      current: widget.settings.locale?.languageCode,
      onSelected: (v) =>
          widget.settings.setLocale(v == null ? null : Locale(v as String)),
    );
  }

  void _pickTheme(BuildContext context, AppLocalizations l10n) {
    final cur = widget.settings.themeMode == ThemeMode.light
        ? 'light'
        : widget.settings.themeMode == ThemeMode.dark
            ? 'dark'
            : 'system';
    _showTVPicker(
      context: context,
      title: l10n.selectTheme,
      items: [
        _PickItem(
            label: l10n.system,
            value: 'system',
            icon: Icons.brightness_auto_rounded),
        _PickItem(
            label: l10n.light, value: 'light', icon: Icons.light_mode_rounded),
        _PickItem(
            label: l10n.dark, value: 'dark', icon: Icons.dark_mode_rounded),
      ],
      current: cur,
      onSelected: (v) => widget.settings.setThemeMode(v == 'light'
          ? ThemeMode.light
          : v == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system),
    );
  }

  void _managePermissions(BuildContext context, AppLocalizations l10n) {
    openAppSettings();
  }

  // ─── TV Picker Dialog ──────────────────────────────────────────────────────

  void _showTVPicker({
    required BuildContext context,
    required String title,
    required List<_PickItem> items,
    required dynamic current,
    required void Function(dynamic) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => _TVPickerDialog(
        title: title,
        items: items,
        current: current,
        isDark: isDark,
        onSelected: (v) {
          onSelected(v);
          setState(() {});
        },
      ),
    );
  }
}

// ─── TV Picker Dialog ─────────────────────────────────────────────────────────

class _TVPickerDialog extends StatefulWidget {
  final String title;
  final List<_PickItem> items;
  final dynamic current;
  final bool isDark;
  final void Function(dynamic) onSelected;

  const _TVPickerDialog({
    required this.title,
    required this.items,
    required this.current,
    required this.isDark,
    required this.onSelected,
  });

  @override
  State<_TVPickerDialog> createState() => _TVPickerDialogState();
}

class _TVPickerDialogState extends State<_TVPickerDialog> {
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.items.length, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sel = widget.items.indexWhere((i) => i.value == widget.current);
      _nodes[sel < 0 ? 0 : sel].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ...widget.items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final selected = item.value == widget.current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Focus(
                  focusNode: _nodes[i],
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                        i < _nodes.length - 1) {
                      _nodes[i + 1].requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                        i > 0) {
                      _nodes[i - 1].requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      Navigator.pop(context);
                      widget.onSelected(item.value);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.goBack ||
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.pop(context);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSelected(item.value);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.15)
                              : hasFocus
                                  ? color.withValues(alpha: 0.08)
                                  : color.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (selected || hasFocus)
                                ? color.withValues(alpha: hasFocus ? 0.8 : 0.4)
                                : color.withValues(alpha: 0.1),
                            width: hasFocus ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(item.icon,
                              size: 20,
                              color:
                                  selected || hasFocus ? color : Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: selected || hasFocus ? color : null,
                                  ))),
                          if (selected)
                            Icon(Icons.check_circle_rounded,
                                color: color, size: 20),
                        ]),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Close Button ─────────────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;
  final KeyEventResult Function(KeyEvent) onKey;

  const _CloseButton({
    required this.focusNode,
    required this.label,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onTap();
          return KeyEventResult.handled;
        }
        return onKey(event);
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: hasFocus ? color : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: hasFocus
                  ? null
                  : Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: hasFocus ? Colors.white : color,
                  )),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _PanelItem {
  final FocusNode focusNode;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final KeyEventResult Function(KeyEvent) onKey;

  const _PanelItem({
    required this.focusNode,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    required this.onKey,
    this.subtitle,
  });
}

class _PickItem {
  final String label;
  final dynamic value;
  final IconData icon;
  const _PickItem(
      {required this.label, required this.value, required this.icon});
}
