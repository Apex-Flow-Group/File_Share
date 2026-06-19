import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/transfer_progress.dart';
import '../services/transfer_progress_service.dart';

/// يعرض شريط تقدم الاستقبال عائماً فوق كل شيء
/// يُستدعى مرة واحدة في main.dart كـ wrapper
class TransferProgressOverlay extends StatefulWidget {
  final Widget child;
  const TransferProgressOverlay({required this.child, super.key});

  @override
  State<TransferProgressOverlay> createState() =>
      _TransferProgressOverlayState();
}

class _TransferProgressOverlayState extends State<TransferProgressOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const _ReceiveProgressFloating(),
      ],
    );
  }
}

// ─── الـ Widget العائم الفعلي ──────────────────────────────────────────────────

class _ReceiveProgressFloating extends StatefulWidget {
  const _ReceiveProgressFloating();

  @override
  State<_ReceiveProgressFloating> createState() =>
      _ReceiveProgressFloatingState();
}

class _ReceiveProgressFloatingState extends State<_ReceiveProgressFloating>
    with SingleTickerProviderStateMixin {
  final _svc = TransferProgressService();
  late AnimationController _anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  TransferProgress? _progress;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _svc.progressStream.listen((p) {
      if (!mounted) {
        return;
      }
      // أظهر فقط عند الاستقبال (ليس الإرسال)
      final show = p != null && !_svc.isSending;
      setState(() => _progress = show ? p : null);
      if (show) {
        _anim.forward();
      } else {
        _anim.reverse();
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_progress == null && !_anim.isAnimating) {
      return const SizedBox.shrink();
    }

    // يحسب المسافة من الأسفل: فوق الـ navbar + safe area + هامش
    final safeBottom = MediaQuery.of(context).padding.bottom;
    const navbarHeight = kBottomNavigationBarHeight;

    return Positioned(
      left: 12,
      right: 12,
      bottom: safeBottom + navbarHeight + 10,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: _buildCard(context),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final p = _progress;
    if (p == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;
    final pct = p.percentage;

    // Material يمنع وراثة TextDecoration.underline من الـ Stack
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                  .withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.25 : 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── صف العنوان ──────────────────────────────────────
                Row(
                  children: [
                    // أيقونة
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // اسم الملف + اسم الجهاز
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (_svc.senderDeviceName != null &&
                              _svc.senderDeviceName!.isNotEmpty)
                            Text(
                              '← ${_svc.senderDeviceName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: color.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          Text(
                            '${_formatSize(p.transferredBytes)} / ${_formatSize(p.totalBytes)}  •  ${p.speedFormatted}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // النسبة
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // زر الإلغاء
                    GestureDetector(
                      onTap: () => _svc.cancelReceive(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ─── شريط التقدم ─────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 5),
                // ─── الوقت المتبقي ────────────────────────────────────
                Text(
                  p.remainingTimeFormatted,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
