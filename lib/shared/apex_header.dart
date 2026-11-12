import 'package:flutter/material.dart';

/// The head of every screen and sheet, one look everywhere. It fills the top
/// of what holds it: behind a phone's status bar, or under a sheet's handle
/// ([ApexSheetTop]); both reach it as its top padding, so the screen above
/// it must not take that padding away (no SafeArea top over it).
class ApexHeader extends StatelessWidget {
  const ApexHeader({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.detail,
    this.leading,
    this.trailing = const [],
    this.inset = 20,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  /// A fainter line under [subtitle], such as an address.
  final String? detail;

  /// Before the icon, such as back.
  final Widget? leading;
  final List<Widget> trailing;

  /// From the side edges, to start in line with the content below it.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final faint = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall;
    return Container(
      padding: EdgeInsets.fromLTRB(
          inset, MediaQuery.paddingOf(context).top + 16, inset, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]
              : [color.withValues(alpha: 0.12), color.withValues(alpha: 0.03)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small?.copyWith(color: faint)),
                if (detail != null)
                  Text(detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small?.copyWith(
                          color: faint.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// A sheet's top: its handle, drawn on [header] when there is one. The sheet
/// clips to its curve (Clip.antiAlias) so the header's corners follow it.
class ApexSheetTop extends StatelessWidget {
  const ApexSheetTop({this.header, super.key});

  final Widget? header;

  static const _handleTop = 12.0;

  @override
  Widget build(BuildContext context) {
    final handle = Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
    if (header == null) {
      return Padding(
        padding: const EdgeInsets.only(top: _handleTop, bottom: 8),
        child: handle,
      );
    }
    final media = MediaQuery.of(context);
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [
          // The handle's room is the header's top padding, as the status bar
          // is on a screen.
          MediaQuery(
            data: media.copyWith(
                padding: media.padding.copyWith(top: _handleTop)),
            child: header!,
          ),
          // Positioned: passthrough would stretch it across the sheet.
          Positioned(top: _handleTop, child: handle),
        ],
      ),
    );
  }
}
