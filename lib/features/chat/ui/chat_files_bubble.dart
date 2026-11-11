import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/file_ui_utils.dart';
import '../../send/ui/send_outcome_message.dart';
import '../logic/chat_store.dart';

/// A line of files in a chat: received ones can be opened, mine show how
/// the send ended.
class ChatFilesBubble extends StatelessWidget {
  const ChatFilesBubble({
    required this.message,
    required this.canOpenFolder,
    required this.canRetry,
    required this.onOpen,
    required this.onOpenFolder,
    required this.onRetry,
    super.key,
  });

  final ChatMessage message;

  /// False on the TV, which has no app that opens folders.
  final bool canOpenFolder;

  /// False on the TV: it only receives and shows.
  final bool canRetry;
  final void Function(ChatFile) onOpen;
  final void Function(ChatFile) onOpenFolder;
  final void Function(ChatMessage) onRetry;

  /// Names shown before "and N more".
  static const shownNames = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hint = Theme.of(context).hintColor;
    final files = message.files;
    final mine = message.mine;
    final failure = message.filesFailure;
    final total = files.fold<int>(0, (s, f) => s + f.size);
    final background = mine
        ? scheme.primary.withValues(alpha: isDark ? 0.35 : 0.14)
        : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F2));
    // A folder sent as a zip, or a copied text, is gone once sent: retrying
    // would fail the same way, so it is not offered.
    final retry = canRetry &&
        failure != null &&
        ChatStore.retryHelps(failure) &&
        message.undelivered.every((f) => File(f.path).existsSync());

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                  border: failure != null ? Border.all(color: Colors.red.withValues(alpha: 0.6)) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(files.length == 1 ? Icons.insert_drive_file_rounded : Icons.file_copy_rounded,
                        size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final f in files.take(shownNames))
                            Text(f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if (files.length > shownNames)
                            Text(l10n.chatMoreFiles(files.length - shownNames),
                                style: TextStyle(fontSize: 13, color: hint)),
                          Text(FileUiUtils.formatFileSize(total), style: TextStyle(fontSize: 12, color: hint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!mine)
                Wrap(spacing: 4, children: [
                  if (files.length == 1)
                    TextButton.icon(
                      onPressed: () => onOpen(files.single),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(l10n.openFile),
                    ),
                  if (canOpenFolder)
                    TextButton.icon(
                      onPressed: () => onOpenFolder(files.first),
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: Text(l10n.openFolder),
                    ),
                ]),
              if (mine && message.status == ChatStatus.sending)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.sending, style: TextStyle(fontSize: 12, color: hint)),
                ),
              if (failure != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      sendOutcomeMessage(l10n, failure, sent: '', failed: l10n.chatFilesFailed),
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
                // Some of the batch arrived before it stopped; a retry sends the rest.
                if (message.delivered > 0)
                  Text(l10n.chatFilesDelivered(message.delivered, files.length),
                      style: TextStyle(fontSize: 12, color: hint)),
                if (retry)
                  TextButton.icon(
                    onPressed: () => onRetry(message),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.retry),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
