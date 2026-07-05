import 'package:flutter/material.dart';

import '../../core/core_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/transfer_progress_service.dart';
import '../../services/update_service.dart';
import '../../shared/apex_bottom_sheet.dart';
import '../../shared/file_ui_utils.dart';

/// Contains all bottom-sheet dialogs used by HomeScreen.
mixin HomeDialogs<T extends StatefulWidget> on State<T> {
  bool _isFileReceivedSheetOpen = false;
  int _fileReceivedSheetGeneration = 0;

  // ─── File Received Sheet ───────────────────────────────────────────────────

  void showFileReceivedSheet(FileReceivedEvent event) async {
    if (_isFileReceivedSheetOpen) {
      _isFileReceivedSheetOpen = false;
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) {
        return;
      }
    }
    _showFileReceivedSheetInternal(event);
  }

  /// Called when the user taps "Open Files" in the sheet.
  void onOpenFilesFromSheet();

  void _showFileReceivedSheetInternal(FileReceivedEvent event) {
    final l10n = AppLocalizations.of(context);
    final sepIndex = event.filePath.lastIndexOf(RegExp(r'[/\\]'));
    final displayPath = sepIndex == -1
        ? event.filePath
        : event.filePath
            .substring(0, sepIndex)
            .replaceAll('/storage/emulated/0/', '');

    _isFileReceivedSheetOpen = true;
    _fileReceivedSheetGeneration++;
    final myGeneration = _fileReceivedSheetGeneration;

    ApexBottomSheet.showStyled(
      context,
      headerIcon: Icons.check_circle_rounded,
      headerColor: Colors.green,
      headerTitle: l10n.fileReceived,
      isDismissible: true,
      enableDrag: false,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(event.fileName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(FileUiUtils.formatFileSize(event.fileSize),
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 10),
        Text('${l10n.from}: ${event.fromDevice}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600])),
        Text('${l10n.savedIn}: $displayPath',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ]),
      actions: [
        Expanded(
            child: FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onOpenFilesFromSheet();
          },
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: Text(l10n.openFiles,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(l10n.close, maxLines: 1, overflow: TextOverflow.ellipsis),
        )),
      ],
    ).whenComplete(() {
      if (myGeneration == _fileReceivedSheetGeneration) {
        _isFileReceivedSheetOpen = false;
      }
    });
  }

  // ─── Connection Request Dialog ─────────────────────────────────────────────

  void showConnectionRequestDialog(ConnectionRequest request) {
    final l10n = AppLocalizations.of(context);
    final sizeStr = request.fileSize > 0
        ? FileUiUtils.formatFileSize(request.fileSize)
        : '';
    final isBatch = request.fileCount > 1;

    ApexBottomSheet.showStyled(
      context,
      headerIcon: Icons.file_download_rounded,
      headerColor: Colors.blue,
      headerTitle: l10n.connectionRequest,
      headerSubtitle: l10n.acceptConnection,
      isDismissible: false,
      enableDrag: false,
      content: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.withValues(alpha: 0.15),
                child: const Icon(Icons.smartphone_rounded,
                    color: Colors.blue, size: 16)),
            const SizedBox(width: 10),
            Text(request.device.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          if (isBatch) ...[
            Row(children: [
              const Icon(Icons.folder_rounded, size: 15, color: Colors.blue),
              const SizedBox(width: 6),
              Text(
                  '${request.fileCount} ${l10n.localeName == 'ar' ? 'ملفات' : 'files'}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            if (request.fileNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...request.fileNames.map((name) => Padding(
                    padding: const EdgeInsets.only(left: 21, bottom: 2),
                    child: Text(name.trim(),
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  )),
            ],
          ] else ...[
            Row(children: [
              const Icon(Icons.insert_drive_file_rounded,
                  size: 15, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(request.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13))),
            ]),
          ],
          if (sizeStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sizeStr,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                    fontSize: 13)),
          ],
        ]),
      ),
      actions: [
        Expanded(
            child: OutlinedButton(
          onPressed: () {
            request.onResponse(false);
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(l10n.reject),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: FilledButton(
          onPressed: () {
            request.onResponse(true);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(l10n.accept),
        )),
      ],
    );
  }

  // ─── Update Available Sheet ────────────────────────────────────────────────

  void showUpdateAvailableSheet() {
    final isAr = AppLocalizations.of(context).localeName == 'ar';
    final color = Theme.of(context).colorScheme.primary;
    ApexBottomSheet.show(context,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.system_update_rounded, size: 36, color: color)),
          const SizedBox(height: 14),
          Text(isAr ? 'تحديث جديد متاح' : 'New Update Available',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              isAr
                  ? 'يوجد إصدار جديد من Apex File Share'
                  : 'A new version of Apex File Share is ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                UpdateService.instance.startFlexibleDownload();
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(isAr ? 'تحديث الآن' : 'Update Now'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(isAr ? 'لاحقاً' : 'Later'),
            )),
          ]),
        ]));
  }

  // ─── Update Ready Sheet ────────────────────────────────────────────────────

  void showUpdateReadySheet() {
    if (!mounted) {
      return;
    }
    final isAr = AppLocalizations.of(context).localeName == 'ar';
    final isBusy = TransferProgressService().isTransferring;
    ApexBottomSheet.show(context,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.download_done_rounded,
                  size: 36, color: Colors.green)),
          const SizedBox(height: 14),
          Text(isAr ? 'التحديث جاهز' : 'Update Ready',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              isBusy
                  ? (isAr
                      ? 'سيُثبَّت التحديث تلقائياً بعد انتهاء الإرسال'
                      : 'Update will install after transfer finishes')
                  : (isAr
                      ? 'التحديث محمّل وجاهز للتثبيت'
                      : 'The update is downloaded and ready to install'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 22),
          if (!isBusy) ...[
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    UpdateService.instance.completeUpdate();
                  },
                  icon: const Icon(Icons.install_mobile_rounded, size: 18),
                  label: Text(isAr ? 'تثبيت الآن' : 'Install Now'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
            const SizedBox(height: 8),
          ],
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(isBusy
                    ? (isAr ? 'حسناً' : 'OK')
                    : (isAr ? 'لاحقاً' : 'Later')),
              )),
        ]));
  }
}
