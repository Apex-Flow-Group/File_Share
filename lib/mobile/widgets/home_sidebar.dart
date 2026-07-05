import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

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
class SidebarActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SidebarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            Icon(icon,
                size: 18, color: isDark ? Colors.white54 : Colors.black45),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black45,
                )),
          ]),
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

/// تبديل نوع الشبكة WiFi / LAN (Desktop)
class NetworkModeTile extends StatelessWidget {
  final SettingsService settings;
  final VoidCallback onChanged;
  const NetworkModeTile(
      {required this.settings, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final isWifi = settings.networkMode == NetworkMode.wifi;
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  isWifi ? Icons.wifi_rounded : Icons.cable_rounded,
                  size: 15,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'نوع الشبكة' : 'Network',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ModeBtn(
                      icon: Icons.wifi_rounded,
                      label: isAr ? 'واي فاي' : 'WiFi',
                      selected: isWifi,
                      onTap: () {
                        settings.setNetworkMode(NetworkMode.wifi);
                        onChanged();
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModeBtn(
                      icon: Icons.cable_rounded,
                      label: isAr ? 'شبكة' : 'LAN',
                      selected: !isWifi,
                      onTap: () {
                        settings.setNetworkMode(NetworkMode.ethernet);
                        onChanged();
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.25 : 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16,
              color: selected
                  ? color
                  : (isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color:
                  selected ? color : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ]),
      ),
    );
  }
}
