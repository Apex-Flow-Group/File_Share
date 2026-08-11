import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/apex_bottom_sheet.dart';

/// Bottom sheet for confirming file deletion with option to delete from device.
///
/// Returns `null` if cancelled, or a [DeleteFilesResult] with the user's choice.
class DeleteFilesResult {
  final bool deleteFromDevice;
  const DeleteFilesResult({required this.deleteFromDevice});
}

class DeleteFilesSheet {
  DeleteFilesSheet._();

  /// Shows the delete confirmation bottom sheet.
  ///
  /// Returns [DeleteFilesResult] if confirmed, `null` if cancelled.
  static Future<DeleteFilesResult?> show(
    BuildContext context, {
    required int fileCount,
  }) async {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.localeName == 'ar';
    bool deleteFromDevice = false;

    final ok = await ApexBottomSheet.showStyled<bool>(
      context,
      headerIcon: Icons.delete_rounded,
      headerColor: Colors.red,
      headerTitle: l10n.deleteFiles,
      headerSubtitle: '$fileCount ${l10n.files}',
      content: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Text(
                isAr
                    ? 'هل تريد حذف $fileCount ملفات؟'
                    : 'Delete $fileCount files?',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android_rounded,
                      size: 20,
                      color: deleteFromDevice ? Colors.red : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'حذف من ذاكرة الجهاز أيضاً'
                          : 'Also delete from device storage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: deleteFromDevice ? Colors.red : null,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: deleteFromDevice,
                    activeTrackColor: Colors.red.withValues(alpha: 0.5),
                    thumbColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? Colors.red : null,
                    ),
                    onChanged: (v) => setSheetState(() => deleteFromDevice = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(l10n.cancel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: Text(l10n.delete),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );

    if (ok == true) {
      return DeleteFilesResult(deleteFromDevice: deleteFromDevice);
    }
    return null;
  }
}
