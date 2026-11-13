import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/apex_bottom_sheet.dart';

/// Bottom sheet for confirming file deletion.
class DeleteFilesSheet {
  DeleteFilesSheet._();

  /// Shows the delete confirmation bottom sheet.
  ///
  /// Returns `true` only if the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required int fileCount,
  }) async {
    final l10n = AppLocalizations.of(context);

    final ok = await ApexBottomSheet.showStyled<bool>(
      context,
      headerIcon: Icons.delete_rounded,
      headerColor: Colors.red,
      headerTitle: l10n.deleteFiles,
      headerSubtitle: '$fileCount',
      content: Column(
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
                l10n.deleteFilesConfirm(fileCount),
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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

    return ok == true;
  }
}
