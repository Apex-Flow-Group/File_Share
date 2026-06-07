import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/transfer_progress.dart';
import '../services/transfer_progress_service.dart';

class TransferProgressOverlay extends StatefulWidget {
  final Widget child;
  const TransferProgressOverlay({required this.child, super.key});

  @override
  State<TransferProgressOverlay> createState() => _TransferProgressOverlayState();
}

class _TransferProgressOverlayState extends State<TransferProgressOverlay>
    with SingleTickerProviderStateMixin {
  final _progressService = TransferProgressService();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        StreamBuilder<TransferProgress?>(
          stream: _progressService.progressStream,
          builder: (context, snapshot) {
            final progress = snapshot.data;
            if (progress == null) {
              _slideController.reverse();
              return const SizedBox.shrink();
            }
            _slideController.forward();
            final svc = _progressService;
            final isMulti = svc.totalFiles > 1;
            return Positioned(
              left: 16, right: 16, bottom: 80,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildProgressCard(progress, isMulti, svc),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressCard(TransferProgress progress, bool isMulti, TransferProgressService svc) {
    final color = Theme.of(context).colorScheme.primary;
    final overallPct = isMulti
        ? ((svc.currentFileIndex + progress.percentage / 100) / svc.totalFiles * 100).clamp(0.0, 100.0)
        : progress.percentage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header ───────────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.upload_rounded, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (isMulti) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${svc.currentFileIndex + 1}/${svc.totalFiles}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            progress.fileName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        '${(progress.transferredBytes / 1024 / 1024).toStringAsFixed(1)} / ${(progress.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB  •  ${progress.speedFormatted}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${progress.percentage.toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _progressService.cancelTransfer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ]),
              const SizedBox(height: 10),
              // ─── Current file bar ──────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.percentage / 100,
                  minHeight: 5,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              // ─── Overall bar (multi only) ──────────────────────────────
              if (isMulti) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallPct / 100,
                    minHeight: 3,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.4)),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isMulti)
                    Text('الكل: ${overallPct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)))
                  else
                    Text(progress.speedFormatted,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        )),
                  Text('متبقي ${progress.remainingTimeFormatted}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
