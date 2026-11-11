import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/apex_core.dart';
import '../../../features/send/data/send_http.dart';
import '../../../features/send/logic/send_folder.dart';
import '../../../features/send/ui/send_outcome_message.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../services/desktop_notification_service.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../shared/device_look.dart';
import '../../../utils/path_name.dart';
import '../tv_apps_dialog.dart';
import '../tv_chat_dialog.dart';
import '../tv_file_browser.dart';
import '../tv_focusable_widgets.dart';

/// TV device card that shows a device and handles send actions via remote.
class TVDeviceCard extends StatefulWidget {
  final Device device;
  final bool isActive;
  final bool isPinned;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final bool isGloballyBusy;
  final bool autofocus;
  final FocusNode? contentFocusNode;
  final VoidCallback? onBackToSidebar;
  const TVDeviceCard({
    required this.device,
    this.isActive = true,
    this.isPinned = false,
    this.onPin,
    this.onUnpin,
    this.isGloballyBusy = false,
    this.autofocus = false,
    this.contentFocusNode,
    this.onBackToSidebar,
    super.key,
  });

  @override
  State<TVDeviceCard> createState() => _TVDeviceCardState();
}

class _TVDeviceCardState extends State<TVDeviceCard> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.contentFocusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.contentFocusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          _showSendOptions(context);
          return KeyEventResult.handled;
        }
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final toSidebarKey = isRtl
            ? LogicalKeyboardKey.arrowRight
            : LogicalKeyboardKey.arrowLeft;
        if (event.logicalKey == toSidebarKey) {
          widget.onBackToSidebar?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: hasFocus
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.2), blurRadius: 12)
                  ],
                )
              : null,
          child: _TVDeviceTile(
            device: widget.device,
            isActive: widget.isActive,
            isPinned: widget.isPinned,
          ),
        );
      }),
    );
  }

  void _showSendOptions(BuildContext context) {
    // One send at a time, like the phone card. A dialog with the send choices
    // missing would not say why, so none opens until the other send ends.
    if (widget.isActive && widget.isGloballyBusy) {
      return;
    }
    // Nothing to send to an offline device, but pinning stays reachable, so an
    // old device that never comes back can be unpinned.
    final canSend = widget.isActive && !widget.device.versionMismatch;
    final togglePin = widget.isPinned ? widget.onUnpin : widget.onPin;
    if (!canSend && togglePin == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (dialogContext) => _TVSendOptionsDialog(
        title: widget.device.name,
        isDark: isDark,
        color: color,
        l10n: l10n,
        canSend: canSend,
        onSendFile: () {
          Navigator.pop(dialogContext);
          _sendFile();
        },
        onSendApp: () {
          Navigator.pop(dialogContext);
          _sendApp();
        },
        onSendFolder: () {
          Navigator.pop(dialogContext);
          _sendFolder();
        },
        isPinned: widget.isPinned,
        onOpenChat: canSend && widget.device.isMdns
            ? () {
                Navigator.pop(dialogContext);
                TVChatDialog.show(context, widget.device);
              }
            : null,
        onTogglePin: togglePin == null
            ? null
            : () {
                Navigator.pop(dialogContext);
                togglePin();
              },
      ),
    );
  }

  Future<void> _sendFile() async {
    final paths = await showTVFileBrowser(context);
    if (paths == null || paths.isEmpty || !mounted) {
      return;
    }

    final outcome = await ApexCore.instance.sendFiles(paths, widget.device);
    final ok = outcome == SendOutcome.sent;
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      showSendOutcome(context, outcome,
          sent: l10n.fileSentSuccess,
          failed: l10n.fileSendFailed);
    }
    final label = paths.length == 1
        ? fileNameOf(paths.first)
        : '${paths.length} files';
    if (ok) {
      await DesktopNotificationService.instance.showFileSent(label);
    } else {
      await DesktopNotificationService.instance.showSendFailed(label);
    }
    TransferProgressService().clearProgress();
  }

  Future<void> _sendApp() async {
    if (!mounted) {
      return;
    }
    final selectedApps = await showTVAppsDialog(context);
    if (!mounted || selectedApps == null || selectedApps.isEmpty) {
      return;
    }
    final outcome = await ApexCore.instance.sendNamedFiles(
        [for (final a in selectedApps) (path: a.file.path, name: '${a.name}.apk')], widget.device);
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    showSendOutcome(context, outcome,
        sent: l10n.appSent,
        failed: l10n.sendFailed);
    TransferProgressService().clearProgress();
  }

  Future<void> _sendFolder() async {
    final folderPath = await showTVFolderBrowser(context);
    if (folderPath == null || !mounted) {
      return;
    }
    // Zipping a big folder takes a while and shows no transfer progress yet.
    var compressing = true;
    final compressingText = AppLocalizations.of(context).compressingFolder;
    // Held now: the card may leave the list while zipping, and the dialog
    // cannot be closed with Back, so it must close even then.
    final navigator = Navigator.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(compressingText)),
          ]),
        ),
      ),
    ));
    void closeCompressing() {
      if (compressing) {
        compressing = false;
        navigator.pop();
      }
    }

    try {
      final (:outcome, :label) =
          await sendFolderZipped(folderPath, widget.device, onZipped: closeCompressing);
      closeCompressing();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showSendOutcome(context, outcome, sent: l10n.folderSent, failed: l10n.sendFailed);
      }
      if (outcome == SendOutcome.sent) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
      }
    } finally {
      closeCompressing();
      TransferProgressService().clearProgress();
    }
  }
}

// ─── TV Send Options Dialog ───────────────────────────────────────────────────

class _TVSendOptionsDialog extends StatelessWidget {
  final String title;
  final bool isDark;
  final Color color;
  final AppLocalizations l10n;
  final bool canSend;
  final VoidCallback onSendFile;
  final VoidCallback onSendApp;
  final VoidCallback onSendFolder;
  final bool isPinned;
  final VoidCallback? onTogglePin;

  /// Null when the device cannot chat (offline, another version, Nearby only).
  final VoidCallback? onOpenChat;

  const _TVSendOptionsDialog({
    required this.title,
    required this.isDark,
    required this.color,
    required this.l10n,
    required this.canSend,
    required this.onSendFile,
    required this.onSendApp,
    required this.onSendFolder,
    required this.isPinned,
    required this.onTogglePin,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            if (canSend) ...[
              TVDialogOption(
                // The TV browser picks several files, sent at once.
                icon: Icons.upload_file_rounded,
                label: l10n.sendFilesNow,
                color: color,
                autofocus: true,
                onTap: onSendFile,
              ),
              const SizedBox(height: 8),
              TVDialogOption(
                icon: Icons.android_rounded,
                label: l10n.sendApp,
                color: const Color(0xFF34C759),
                autofocus: false,
                onTap: onSendApp,
              ),
              const SizedBox(height: 8),
              TVDialogOption(
                icon: Icons.folder_zip_rounded,
                label: l10n.sendFolder,
                color: const Color(0xFF5856D6),
                autofocus: false,
                onTap: onSendFolder,
              ),
            ],
            if (onOpenChat != null) ...[
              const SizedBox(height: 8),
              TVDialogOption(
                icon: Icons.chat_bubble_rounded,
                // Read only on the TV: it shows messages, it does not chat.
                label: l10n.chatMessages,
                color: const Color(0xFF00897B),
                autofocus: false,
                onTap: onOpenChat!,
              ),
            ],
            if (onTogglePin != null) ...[
              if (canSend) const SizedBox(height: 8),
              // The phone card pins by touch; the remote reaches it only here.
              TVDialogOption(
                icon: isPinned ? Icons.star_border_rounded : Icons.star_rounded,
                label: isPinned ? l10n.unpinDevice : l10n.pinDevice,
                color: Colors.grey,
                autofocus: !canSend,
                onTap: onTogglePin!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Card body ────────────────────────────────────────────────────────────────

class _TVDeviceTile extends StatelessWidget {
  final Device device;
  final bool isActive;
  final bool isPinned;

  const _TVDeviceTile({
    required this.device,
    required this.isActive,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = deviceColor(device);
    final hostname = device.hostname;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Opacity(
        opacity: isActive && !device.versionMismatch ? 1.0 : 0.45,
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(deviceIcon(device), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (hostname != null && hostname.isNotEmpty && hostname != device.name)
                  Text(hostname,
                      style: TextStyle(fontSize: 12, color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  !isActive
                      ? l10n.deviceOffline
                      : device.versionMismatch
                          ? l10n.versionDiffers
                          : device.isNearby
                              ? l10n.directConnection
                              : device.ip,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          if (isPinned) Icon(Icons.star_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isActive && !device.versionMismatch ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ]),
      ),
    );
  }
}
