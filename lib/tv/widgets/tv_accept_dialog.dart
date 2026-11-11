import 'package:flutter/material.dart';

import '../../core/core_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/closes_with_request.dart';
import '../../shared/file_ui_utils.dart';
import 'tv_focusable_widgets.dart';

/// Asks the TV user, with the remote, whether to receive [request].
/// The focus starts on Reject, so a stray OK never accepts; Back refuses.
class TVAcceptDialog extends StatelessWidget {
  const TVAcceptDialog({required this.request, super.key});

  final ConnectionRequest request;

  static Future<void> ask(BuildContext context, ConnectionRequest request) async {
    // The asker already stopped waiting: an answer here would be ignored.
    if (request.isClosed) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TVAcceptDialog(request: request),
    );
    request.onResponse(accepted ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Connecting, opening the folder and receiving are separate answers, so
    // they never share a title.
    final (icon, title, question) = switch (request.kind) {
      RequestKind.connect => (Icons.link_rounded, l10n.connectionRequest, l10n.acceptConnection),
      RequestKind.shareFolder => (
          Icons.folder_shared_rounded,
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
      RequestKind.chat => (Icons.chat_bubble_rounded, l10n.chatRequestTitle, l10n.chatRequestQuestion),
    };
    final singleName =
        request.kind == RequestKind.files && request.fileCount == 1 ? request.fileName : '';
    return ClosesWithRequest(
      request: request,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.blue, size: 40),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Text(request.device.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                // The address comes from the connection; a name alone can be claimed.
                if (request.device.ip.isNotEmpty)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(request.device.ip,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ),
                const SizedBox(height: 12),
                Text(question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (singleName.isNotEmpty)
                  Text(singleName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14)),
                if (request.fileSize > 0)
                  Text(FileUiUtils.formatFileSize(request.fileSize),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.blue, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TVDialogButton(
                        label: l10n.reject,
                        color: Colors.red,
                        autofocus: true,
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TVDialogButton(
                        label: l10n.accept,
                        color: Colors.blue,
                        autofocus: false,
                        onTap: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
