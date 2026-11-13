import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../features/chat/logic/chat_key.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/transfer_progress_service.dart';
import '../../services/update_service.dart';
import '../../shared/apex_bottom_sheet.dart';
import '../../shared/apex_icons.dart';
import '../../shared/closes_with_request.dart';
import '../../shared/file_ui_utils.dart';
import '../../utils/file_utils.dart';

/// Contains all bottom-sheet dialogs used by HomeScreen.
mixin HomeDialogs<T extends StatefulWidget> on State<T> {
  /// The open "file received" sheet: a newer one removes exactly this route,
  /// not whatever is on top (Settings opened over it used to close instead).
  Route<dynamic>? _fileReceivedRoute;
  int _fileReceivedSheetGeneration = 0;

  Widget _rememberRoute(Widget child) => Builder(builder: (ctx) {
        _fileReceivedRoute = ModalRoute.of(ctx);
        return child;
      });

  // ─── Batch accumulator ─────────────────────────────────────────────────────

  // ─── File Received Sheet ───────────────────────────────────────────────────

  void showFileReceivedSheet(FileReceivedEvent event) {
    final old = _fileReceivedRoute;
    _fileReceivedRoute = null;
    if (old != null && old.isActive) {
      Navigator.of(context).removeRoute(old);
    }

    if (event.batchTotal > 1) {
      _showBatchSummarySheet(event);
    } else {
      _showFileReceivedSheetInternal(event);
    }
  }

  /// The sheet's open button: the file's folder, or the files tab for a batch.
  void onOpenFilesFromSheet([String? filePath]);

  /// The sheet's open button when the files went to a chat (owner decision):
  /// that chat, whose line opens the file and its folder. False when no card
  /// on the send tab holds it any more (the device left the list).
  bool onOpenChatFromSheet(ChatKey key);

  /// Whether a card on the send tab holds the chat [key]: a chat is opened
  /// in its device's card, so without one the button would show nothing.
  bool hasChatCard(ChatKey key);

  /// The sheet's main button: the sender's chat, or [fallback] where the
  /// files have none (Nearby) or its device is not listed.
  Widget _openButton(FileReceivedEvent event, AppLocalizations l10n,
      {required IconData icon, required String label, required VoidCallback fallback}) {
    final found = ApexCore.instance.chat.chatOf(event);
    final chat = found != null && hasChatCard(found) ? found : null;
    return FilledButton.icon(
      onPressed: () {
        Navigator.pop(context);
        if (chat == null || !onOpenChatFromSheet(chat)) {
          fallback();
        }
      },
      icon: Icon(chat == null ? icon : Icons.chat_bubble_rounded, size: 18),
      label: Text(chat == null ? label : l10n.chatOpen, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showFileReceivedSheetInternal(FileReceivedEvent event) {
    final l10n = AppLocalizations.of(context);
    final sepIndex = event.filePath.lastIndexOf(RegExp(r'[/\\]'));
    final displayPath = FileUtils.displayPath(
        sepIndex == -1 ? event.filePath : event.filePath.substring(0, sepIndex));

    _fileReceivedSheetGeneration++;
    final myGeneration = _fileReceivedSheetGeneration;

    ApexBottomSheet.showStyled(
      context,
      headerIcon: Icons.check_circle_rounded,
      headerColor: Colors.green,
      headerTitle: l10n.fileReceived,
      isDismissible: true,
      enableDrag: false,
      content: _rememberRoute(Column(mainAxisSize: MainAxisSize.min, children: [
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
      ])),
      actions: [
        Expanded(
            child: _openButton(event, l10n,
                icon: Icons.folder_open_rounded,
                label: l10n.openFolder,
                fallback: () => onOpenFilesFromSheet(event.filePath))),
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
        _fileReceivedRoute = null;
      }
    });
  }

  // ─── Batch File Received Sheet ─────────────────────────────────────────────

  void _showBatchSummarySheet(FileReceivedEvent lastEvent) {
    final l10n = AppLocalizations.of(context);
    final fromDevice = lastEvent.fromDevice;
    final totalFiles = lastEvent.batchTotal;

    _fileReceivedSheetGeneration++;
    final myGeneration = _fileReceivedSheetGeneration;

    ApexBottomSheet.showStyled(
      context,
      headerIcon: Icons.check_circle_rounded,
      headerColor: Colors.green,
      headerTitle: l10n.filesReceivedTitle(totalFiles),
      isDismissible: true,
      enableDrag: false,
      content: _rememberRoute(Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.folder_rounded, size: 36, color: Colors.green),
        ),
        const SizedBox(height: 10),
        Text('${l10n.from}: $fromDevice',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600])),
      ])),
      actions: [
        Expanded(
            child: _openButton(lastEvent, l10n,
                icon: Icons.folder_rounded,
                label: l10n.openFiles,
                fallback: onOpenFilesFromSheet)),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(l10n.close, maxLines: 1, overflow: TextOverflow.ellipsis),
        )),
      ],
    ).whenComplete(() {
      if (myGeneration == _fileReceivedSheetGeneration) {
        _fileReceivedRoute = null;
      }
    });
  }

  // ─── Connection Request Dialog ─────────────────────────────────────────────

  void showConnectionRequestDialog(ConnectionRequest request) {
    // The asker already stopped waiting: an answer here would be ignored.
    if (request.isClosed) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final sizeStr = request.fileSize > 0
        ? FileUiUtils.formatFileSize(request.fileSize)
        : '';
    final isBatch = request.fileCount > 1;
    // Connecting, opening the folder and receiving are separate answers, so
    // they never share a title.
    final (icon, title, question) = switch (request.kind) {
      RequestKind.connect => (
          Icons.link_rounded,
          l10n.connectionRequest,
          l10n.acceptConnection
        ),
      RequestKind.shareFolder => (
          ApexIcons.sharedFolder,
          l10n.shareAccessTitle,
          request.allowsUploads
              ? l10n.shareAccessDownloadUpload
              : l10n.shareAccessDownload
        ),
      RequestKind.files => (
          Icons.file_download_rounded,
          l10n.incomingFilesTitle,
          l10n.receiveFilesQuestion(request.fileCount)
        ),
      RequestKind.chat => (
          Icons.chat_bubble_rounded,
          l10n.chatRequestTitle,
          l10n.chatRequestQuestion
        ),
    };

    ApexBottomSheet.showStyled(
      context,
      headerIcon: icon,
      headerColor: Colors.blue,
      headerTitle: title,
      headerSubtitle: question,
      isDismissible: false,
      enableDrag: false,
      content: ClosesWithRequest(
        request: request,
        child: Container(
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
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.device.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      // The address comes from the connection, so a device
                      // cannot pose as another by claiming its name alone.
                      if (request.device.ip.isNotEmpty)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(request.device.ip,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ),
                    ]),
              ),
            ]),
            // Owner decision: whoever accepts sees it; accepting is enough.
            if (request.keyChanged) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(l10n.requestNewKey,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ],
            // Only a files request has files to show.
            if (request.kind == RequestKind.files) const SizedBox(height: 10),
            if (request.kind != RequestKind.files)
              const SizedBox.shrink()
            else if (isBatch) ...[
              if (request.fileNames.isNotEmpty) ...[
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
    final l10n = AppLocalizations.of(context);
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
          Text(l10n.updateSheetTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(l10n.updateSheetBody,
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
              label: Text(l10n.updateNow),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(l10n.later),
            )),
          ]),
        ]));
  }

  // ─── Update Ready Sheet ────────────────────────────────────────────────────

  void showUpdateReadySheet() {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
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
          Text(l10n.updateReadyTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              isBusy
                  ? l10n.updateInstallsAfterTransfer
                  : l10n.updateDownloadedReady,
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
                  label: Text(l10n.installNow),
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
                child: Text(isBusy ? l10n.ok : l10n.later),
              )),
        ]));
  }
}
