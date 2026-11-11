import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../features/chat/ui/chat_attach.dart';
import '../../features/chat/ui/device_chat_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../services/clipboard_monitor_service.dart';
import '../../shared/device_look.dart';
import '../../shared/framed_capsule_input.dart';

/// A network device's card while folded: a row like a messaging app's
/// contact. It shows how many messages are new, never their text, which may
/// be a password read by anyone looking (owner decision).
class ChatProfileRow extends StatelessWidget {
  const ChatProfileRow({
    required this.device,
    required this.onOpen,
    required this.onPaste,
    required this.onAttach,
    super.key,
  });

  final Device device;
  final VoidCallback onOpen;
  final VoidCallback onPaste;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = ApexCore.instance.chat;
    final color = deviceColor(device);
    final hint = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final unread = store.unread(device.ip);
        // Blocked: no messages to or from it, so nothing to paste or send.
        final blocked = store.isBlocked(device.ip);
        return Semantics(
          button: true,
          label: l10n.chatOpen,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onOpen,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(deviceIcon(device), color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      unread > 0
                          ? Text(l10n.chatUnread(unread),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.secondary))
                          : Text(device.ip,
                              textDirection: TextDirection.ltr, style: TextStyle(fontSize: 12, color: hint)),
                    ],
                  ),
                ),
                if (!blocked) ...[
                  _RowCircle(icon: Icons.content_paste_rounded, label: l10n.chatPaste, onTap: onPaste),
                  const SizedBox(width: 6),
                  _RowCircle(icon: Icons.add_rounded, label: l10n.chatAttach, onTap: onAttach),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RowCircle extends StatelessWidget {
  const _RowCircle({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FramedCapsuleColors.of(context);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: c.circle,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            // 48dp to touch, as everywhere.
            child: SizedBox.square(dimension: 48, child: Icon(icon, color: c.onCircle, size: 22)),
          ),
        ),
      ),
    );
  }
}

/// The chat inside an opened card: the messages and the message box.
class ChatCardPanel extends StatelessWidget {
  const ChatCardPanel({
    required this.device,
    this.initialText,
    this.initialFiles = const [],
    this.copied,
    this.onCopiedUsed,
    super.key,
  });

  final Device device;
  final String? initialText;
  final List<String> initialFiles;
  final ClipboardItem? copied;
  final void Function({required bool sent})? onCopiedUsed;

  /// Grows with the messages up to here, so the other cards stay in reach.
  static const maxHeight = 420.0;

  @override
  Widget build(BuildContext context) {
    final store = ApexCore.instance.chat;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxHeight),
      child: DeviceChatView(
        store: store,
        device: device,
        pickFiles: pickFilePaths,
        // The same send as every other, so the files show as a line here.
        sendFiles: (paths) => ApexCore.instance.sendFiles(paths, device),
        initialText: initialText,
        initialFiles: initialFiles,
        copied: copied,
        onCopiedUsed: onCopiedUsed,
      ),
    );
  }
}
