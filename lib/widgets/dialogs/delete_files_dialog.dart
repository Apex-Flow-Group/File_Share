import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';


class DeleteFilesDialog extends StatefulWidget {
  final int fileCount;
  final Function(bool) onConfirm;

  const DeleteFilesDialog({
    required this.fileCount, required this.onConfirm, super.key,
  });

  @override
  State<DeleteFilesDialog> createState() => _DeleteFilesDialogState();
}

class _DeleteFilesDialogState extends State<DeleteFilesDialog> {
  bool _deletePermanent = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          border: Border.all(
            color: _deletePermanent
                ? Colors.red.shade700
                : Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: _deletePermanent ? Colors.red.shade700 : Colors.orange.shade700,
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context).deleteFiles,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppLocalizations.of(context).filesCount}: ${widget.fileCount}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    value: _deletePermanent,
                    onChanged: (val) {
                      setState(() => _deletePermanent = val ?? false);
                    },
                    title: Text(
                      AppLocalizations.of(context).deletePermanent,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_deletePermanent)
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade700, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).deleteWarning,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red.shade900,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: Theme.of(context).colorScheme.outline, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: Text(AppLocalizations.of(context).cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onConfirm(_deletePermanent);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deletePermanent
                          ? Colors.red.shade700
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: Text(AppLocalizations.of(context).deleteFiles),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
