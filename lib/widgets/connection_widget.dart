import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/apex_core.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/device.dart';
import '../screens/apps_selection_screen.dart';
import '../services/transfer_progress_service.dart';

enum _Status { idle, sending }

class ConnectionWidget extends StatefulWidget {
  final Device device;
  const ConnectionWidget({required this.device, super.key});

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget>
    with SingleTickerProviderStateMixin {
  _Status _status = _Status.idle;
  late AnimationController _sendAnim;

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _sendAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 14),
            _status == _Status.sending
                ? _buildSendingState()
                : _buildActions(l10n, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final color = _deviceColor;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(_deviceIcon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.device.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(children: [
                _TransportBadge(isNearby: widget.device.isNearby),
                if (!widget.device.isNearby && widget.device.ip.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.device.ip,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n, bool isDark) {
    return Row(
      children: [
        Expanded(child: _ActionButton(
          icon: Icons.folder_open_rounded,
          label: l10n.sendFile,
          color: Theme.of(context).colorScheme.primary,
          isDark: isDark,
          onTap: _sendFile,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ActionButton(
          icon: Icons.android_rounded,
          label: l10n.sendApp,
          color: const Color(0xFF34C759),
          isDark: isDark,
          onTap: _sendApp,
        )),
      ],
    );
  }

  Widget _buildSendingState() {
    return StreamBuilder<dynamic>(
      stream: TransferProgressService().progressStream,
      builder: (context, snapshot) {
        final p = snapshot.data;
        final pct = p?.percentage ?? 0.0;
        final speed = p?.speedFormatted ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text('جاري الإرسال...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              const Spacer(),
              if (speed.isNotEmpty)
                Text(speed,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct > 0 ? pct / 100 : null,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            if (pct > 0) ...[
              const SizedBox(height: 4),
              Text('${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        );
      },
    );
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    setState(() => _status = _Status.sending);
    int success = 0;
    try {
      for (final f in result.files) {
        if (f.path == null) {
          continue;
        }
        if (await ApexCore.instance.sendFile(f.path!, widget.device)) {
          success++;
        }
      }
      if (mounted) {
        _showSnack(
          success == result.files.length
              ? AppLocalizations.of(context).fileSentSuccess
              : AppLocalizations.of(context).fileSendFailed,
          success > 0,
        );
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setState(() => _status = _Status.idle);
      }
    }
  }

  Future<void> _sendApp() async {
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppsSelectionScreen(
          onAppSelected: (apkFile, appName) async {
            if (!mounted) {
              return;
            }
            setState(() => _status = _Status.sending);
            try {
              final ok = await ApexCore.instance
                  .sendFileWithName(apkFile.path, '$appName.apk', widget.device);
              if (!mounted) {
                return;
              }
              _showSnack(
                ok ? AppLocalizations.of(context).appSent
                   : AppLocalizations.of(context).sendFailed,
                ok,
              );
            } finally {
              TransferProgressService().clearProgress();
              if (mounted) {
                setState(() => _status = _Status.idle);
              }
            }
          },
        ),
      ),
    );
  }

  void _showSnack(String msg, bool ok) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  IconData get _deviceIcon {
    switch (widget.device.type.toLowerCase()) {
      case 'tv': return Icons.tv_rounded;
      case 'desktop': return Icons.computer_rounded;
      case 'tablet': return Icons.tablet_rounded;
      default: return Icons.smartphone_rounded;
    }
  }

  Color get _deviceColor {
    switch (widget.device.type.toLowerCase()) {
      case 'tv': return const Color(0xFF5856D6);
      case 'desktop': return const Color(0xFF007AFF);
      case 'tablet': return const Color(0xFFFF9500);
      default: return const Color(0xFF34C759);
    }
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Transport Badge ──────────────────────────────────────────────────────────

class _TransportBadge extends StatelessWidget {
  final bool isNearby;
  const _TransportBadge({required this.isNearby});

  @override
  Widget build(BuildContext context) {
    final color = isNearby ? const Color(0xFF34C759) : const Color(0xFF007AFF);
    final label = isNearby ? 'Nearby' : 'WiFi';
    final icon = isNearby ? Icons.sensors_rounded : Icons.wifi_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
