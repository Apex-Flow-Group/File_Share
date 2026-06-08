import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/apex_core.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/device.dart';
import '../screens/apps_selection_screen.dart';
import '../services/desktop_notification_service.dart';
import '../services/transfer_progress_service.dart';

enum _Status { idle, sending }

class ConnectionWidget extends StatefulWidget {
  final Device device;
  final String? pendingFilePath;
  final VoidCallback? onPendingFileSent;
  final bool isGloballyBusy;
  const ConnectionWidget({
    required this.device,
    this.pendingFilePath,
    this.onPendingFileSent,
    this.isGloballyBusy = false,
    super.key,
  });

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget>
    with SingleTickerProviderStateMixin {
  _Status _status = _Status.idle;
  bool _cancelledByUser =
      false; // منع الـ listener من إعادة التشغيل بعد الإلغاء
  late AnimationController _sendAnim;

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // استعادة الحالة فقط إذا كان هذا الجهاز تحديداً هو المستهدف بالإرسال
    final svc = TransferProgressService();
    if (svc.isSending &&
        svc.isTransferring &&
        svc.targetDeviceId == widget.device.id) {
      _status = _Status.sending;
    }
    // تابع انتهاء الإرسال لتحديث الحالة
    svc.progressStream.listen((p) {
      if (!mounted) {
        return;
      }
      // إذا ألغى المستخدم — لا نعيد التشغيل مهما جاء من الـ stream
      if (_cancelledByUser) {
        if (p == null) {
          // الإرسال انتهى فعلاً — أعد ضبط الـ flag
          _cancelledByUser = false;
        }
        return;
      }
      if (p == null && _status == _Status.sending) {
        setState(() => _status = _Status.idle);
      }
    });
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
            if (widget.pendingFilePath != null &&
                _status == _Status.idle &&
                !widget.isGloballyBusy)
              _buildPendingFileBanner(l10n),
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(children: [
                _TransportBadge(
                  isNearby: widget.device.isNearby,
                  isWifi: widget.device.isMdns,
                ),
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

  Widget _buildPendingFileBanner(AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    final fileName = widget.pendingFilePath!.split('/').last;
    return GestureDetector(
      onTap: _sendPendingFile,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.note_rounded, color: Colors.purple, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAr ? 'إرسال: $fileName' : 'Send: $fileName',
              style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.send_rounded, color: Colors.purple, size: 16),
        ]),
      ),
    );
  }

  Future<void> _sendPendingFile() async {
    final path = widget.pendingFilePath;
    if (path == null) {
      return;
    }
    setState(() => _status = _Status.sending);
    try {
      final ok = await ApexCore.instance.sendFile(path, widget.device);
      if (mounted) {
        _showSnack(
          ok
              ? AppLocalizations.of(context).fileSentSuccess
              : AppLocalizations.of(context).fileSendFailed,
          ok,
        );
        if (ok) {
          widget.onPendingFileSent?.call();
        }
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setState(() => _status = _Status.idle);
      }
    }
  }

  Widget _buildActions(AppLocalizations l10n, bool isDark) {
    // أثناء إرسال جارٍ لجهاز آخر — أظهر حالة انتظار لهذا الجهاز فقط
    final svc = TransferProgressService();
    final isThisDeviceTarget = svc.targetDeviceId == widget.device.id;
    if (widget.isGloballyBusy &&
        _status == _Status.idle &&
        !isThisDeviceTarget) {
      return _buildBusyBar(l10n);
    }
    return Row(
      children: [
        Expanded(
            child: _ActionButton(
          icon: Icons.folder_open_rounded,
          label: l10n.sendFile,
          color: Theme.of(context).colorScheme.primary,
          isDark: isDark,
          onTap: _sendFile,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _ActionButton(
          icon: Icons.android_rounded,
          label: l10n.sendApp,
          color: const Color(0xFF34C759),
          isDark: isDark,
          onTap: _sendApp,
        )),
      ],
    );
  }

  Widget _buildBusyBar(AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          isAr ? 'يوجد إرسال جارٍ...' : 'Transfer in progress...',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }

  Widget _buildSendingState() {
    final isAr = AppLocalizations.of(context).localeName == 'ar';
    final svc = TransferProgressService();

    return StreamBuilder<dynamic>(
      stream: svc.progressStream,
      builder: (context, snapshot) {
        final p = snapshot.data;
        final pct = p?.percentage ?? 0.0;
        final speed = p?.speedFormatted ?? '';
        final total = svc.totalFiles;
        final current = svc.currentFileIndex + 1;
        final isBatch = total > 1;
        final batchPct = isBatch
            ? ((svc.currentFileIndex + (pct / 100)) / total * 100)
                .clamp(0.0, 100.0)
            : pct;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صف العنوان: الحالة + السرعة + زر إلغاء
            Row(children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBatch
                      ? (isAr
                          ? 'ملف $current من $total'
                          : 'File $current of $total')
                      : (isAr ? 'جاري الإرسال...' : 'Sending...'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (speed.isNotEmpty)
                Text(speed,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _cancelledByUser = true;
                  TransferProgressService().cancelTransfer();
                  // أخفِ الشريط فوراً من الـ UI
                  setState(() => _status = _Status.idle);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isAr ? 'إلغاء' : 'Cancel',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ]),

            // اسم الملف الحالي
            if (p?.fileName != null) ...[
              const SizedBox(height: 8),
              Text(
                p!.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // شريط الملف الحالي
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct > 0 ? pct / 100 : null,
                minHeight: 5,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pct > 0 ? '${pct.toStringAsFixed(0)}%' : '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (p != null)
                  Text(
                    p.remainingTimeFormatted,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),

            // شريط الدفعة الكلي — يظهر فقط عند إرسال متعدد
            if (isBatch) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: batchPct / 100,
                        minHeight: 3,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${batchPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
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

    final paths =
        result.files.where((f) => f.path != null).map((f) => f.path!).toList();

    setState(() => _status = _Status.sending);
    try {
      final ok = await ApexCore.instance.sendFiles(paths, widget.device);
      if (mounted) {
        _showSnack(
          ok
              ? AppLocalizations.of(context).fileSentSuccess
              : AppLocalizations.of(context).fileSendFailed,
          ok,
        );
      }
      final label = paths.length == 1
          ? paths.first.split('/').last
          : '${paths.length} files';
      if (ok) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
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
              final ok = await ApexCore.instance.sendFileWithName(
                  apkFile.path, '$appName.apk', widget.device);
              if (!mounted) {
                return;
              }
              _showSnack(
                ok
                    ? AppLocalizations.of(context).appSent
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
      case 'tv':
        return Icons.tv_rounded;
      case 'desktop':
        return Icons.computer_rounded;
      case 'tablet':
        return Icons.tablet_rounded;
      default:
        return Icons.smartphone_rounded;
    }
  }

  Color get _deviceColor {
    switch (widget.device.type.toLowerCase()) {
      case 'tv':
        return const Color(0xFF5856D6);
      case 'desktop':
        return const Color(0xFF007AFF);
      case 'tablet':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFF34C759);
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
  final bool isWifi;
  const _TransportBadge({required this.isNearby, required this.isWifi});

  @override
  Widget build(BuildContext context) {
    // كلاهما متاح
    if (isNearby && isWifi) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _badge(
            context, const Color(0xFF34C759), Icons.sensors_rounded, 'Nearby'),
        const SizedBox(width: 4),
        _badge(context, const Color(0xFF007AFF), Icons.wifi_rounded, 'WiFi'),
      ]);
    }
    if (isNearby) {
      return _badge(
          context, const Color(0xFF34C759), Icons.sensors_rounded, 'Nearby');
    }
    return _badge(context, const Color(0xFF007AFF), Icons.wifi_rounded, 'WiFi');
  }

  Widget _badge(
      BuildContext context, Color color, IconData icon, String label) {
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
