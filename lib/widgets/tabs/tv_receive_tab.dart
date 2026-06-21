import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../models/transfer_progress.dart';
import '../../services/transfer_progress_service.dart';

class TVReceiveTab extends StatefulWidget {
  final Device? localDevice;
  final bool isRunning;
  final VoidCallback? onBackToSidebar;
  final FocusNode? contentFocusNode;
  const TVReceiveTab({
    required this.localDevice,
    required this.isRunning,
    this.onBackToSidebar,
    this.contentFocusNode,
    super.key,
  });

  @override
  State<TVReceiveTab> createState() => _TVReceiveTabState();
}

class _TVReceiveTabState extends State<TVReceiveTab>
    with SingleTickerProviderStateMixin {
  bool _isReceiving = false;
  bool _cancelledByUser = false;
  late AnimationController _pulseAnim;
  late final FocusNode _copyFocus;
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'cancel-receive');

  @override
  void initState() {
    super.initState();
    _copyFocus = widget.contentFocusNode ?? FocusNode(debugLabel: 'copy-ip');
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    TransferProgressService().progressStream.listen((p) {
      if (!mounted) {
        return;
      }
      if (_cancelledByUser) {
        if (p == null) {
          _cancelledByUser = false;
        }
        return;
      }
      final svc = TransferProgressService();
      setState(() => _isReceiving =
          !svc.isSending && p?.status == TransferStatus.transferring);
    });
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    if (widget.contentFocusNode == null) {
      _copyFocus.dispose();
    }
    _cancelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: widget.localDevice == null || !widget.isRunning
                ? _buildNotReady()
                : _buildReady(),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF5856D6);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smartphone_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.receive,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                Text(
                  _isReceiving ? l10n.receiving : l10n.instruction4,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_isReceiving ? Colors.purple : Colors.green)
                    .withValues(alpha: 0.1 + _pulseAnim.value * 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isReceiving ? Colors.purple : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isReceiving ? 'RX' : 'Ready',
                  style: TextStyle(
                    color: _isReceiving ? Colors.purple : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Not Ready ─────────────────────────────────────────────────────────────

  Widget _buildNotReady() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            Text(
              isAr ? 'النظام غير جاهز' : 'System not ready',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'تأكد من تشغيل النظام' : 'Make sure the system is running',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ready ─────────────────────────────────────────────────────────────────

  Widget _buildReady() {
    final l10n = AppLocalizations.of(context);
    final device = widget.localDevice!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(l10n),
          const SizedBox(height: 14),
          _buildDeviceCard(device, l10n),
          const SizedBox(height: 14),
          _buildTipsCard(l10n),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppLocalizations l10n) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isReceiving
                ? [
                    Colors.purple
                        .withValues(alpha: 0.15 + _pulseAnim.value * 0.05),
                    Colors.purple.withValues(alpha: 0.05),
                  ]
                : [
                    Colors.green.withValues(alpha: isDark ? 0.15 : 0.08),
                    Colors.green.withValues(alpha: 0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isReceiving
                ? Colors.purple.withValues(alpha: 0.3)
                : Colors.green.withValues(alpha: 0.2),
          ),
        ),
        child: _isReceiving
            ? _buildReceivingContent()
            : _buildReadyContent(isAr, l10n),
      ),
    );
  }

  Widget _buildReadyContent(bool isAr, AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 36, color: Colors.green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'جاهز للاستقبال' : 'Ready to Receive',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.instruction4,
                style: TextStyle(
                    fontSize: 13, color: Colors.green.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceivingContent() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return StreamBuilder<TransferProgress?>(
      stream: TransferProgressService().progressStream,
      builder: (context, snapshot) {
        final p = snapshot.data;
        final svc = TransferProgressService();
        if (svc.isSending) {
          return _buildReadyContent(isAr, AppLocalizations.of(context));
        }
        final senderName = svc.senderDeviceName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'جاري الاستقبال...' : 'Receiving...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
                      ),
                    ),
                    if (senderName != null && senderName.isNotEmpty)
                      Text(
                        isAr ? 'من: $senderName' : 'From: $senderName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (p != null)
                Text(p.speedFormatted,
                    style: const TextStyle(fontSize: 12, color: Colors.purple)),
              const SizedBox(width: 8),
              // Cancel button — focusable for remote
              _TVFocusableButton(
                focusNode: _cancelFocus,
                onTap: () {
                  _cancelledByUser = true;
                  TransferProgressService().cancelReceive();
                  setState(() => _isReceiving = false);
                },
                color: Colors.red,
                label: isAr ? 'إلغاء' : 'Cancel',
              ),
            ]),
            if (p != null) ...[
              const SizedBox(height: 14),
              Text(p.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: p.percentage / 100,
                  minHeight: 8,
                  backgroundColor: Colors.purple.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(Colors.purple),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${p.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.purple,
                          fontWeight: FontWeight.w600)),
                  Text(p.remainingTimeFormatted,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDeviceCard(Device device, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.phone_android_rounded,
                size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(l10n.thisDevice,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                )),
          ]),
          const SizedBox(height: 14),
          _infoTile(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF007AFF),
            label: l10n.deviceName,
            value: device.name,
          ),
          if (device.ip.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _infoTileWithCopy(
              icon: Icons.wifi_rounded,
              iconColor: const Color(0xFF34C759),
              label: l10n.ipAddress,
              value: device.ip,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTileWithCopy({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
        // Copy button — focusable for TV remote
        _TVFocusableIconButton(
          focusNode: _copyFocus,
          icon: Icons.copy_rounded,
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context).textCopied),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildTipsCard(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF5856D6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tips_and_updates_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Text(l10n.howToReceive,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                )),
          ]),
          const SizedBox(height: 10),
          _tipRow('1', l10n.instruction1),
          _tipRow('2', l10n.instruction3),
          _tipRow('3', l10n.instruction4),
        ],
      ),
    );
  }

  Widget _tipRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF5856D6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5856D6),
                  )),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── TV Focusable Button ──────────────────────────────────────────────────────
// زر صغير يدعم التنقل بالريموت

class _TVFocusableButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Color color;
  final String label;

  const _TVFocusableButton({
    required this.focusNode,
    required this.onTap,
    required this.color,
    required this.label,
  });

  @override
  State<_TVFocusableButton> createState() => _TVFocusableButtonState();
}

class _TVFocusableButtonState extends State<_TVFocusableButton> {
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

// ─── TV Focusable Icon Button ─────────────────────────────────────────────────

class _TVFocusableIconButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onTap;

  const _TVFocusableIconButton({
    required this.focusNode,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_TVFocusableIconButton> createState() => _TVFocusableIconButtonState();
}

class _TVFocusableIconButtonState extends State<_TVFocusableIconButton> {
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
