import 'package:flutter/material.dart';

import '../../services/transfer_progress_service.dart';

/// Reusable widget that displays file transfer progress with batch support.
class TransferProgressIndicator extends StatelessWidget {
  final VoidCallback onCancel;

  const TransferProgressIndicator({required this.onCancel, super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
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
            // Header row: status + speed + cancel button
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
                onTap: onCancel,
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

            // Current file name
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

            // Current file progress bar
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

            // Batch progress bar — shown only for multi-file transfers
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
}
