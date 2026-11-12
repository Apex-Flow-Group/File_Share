import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/apex_core.dart';
import '../../../features/chat/logic/chat_key.dart';
import '../../../features/chat/ui/confirm_block.dart';
import '../../../features/chat/ui/device_chat_view.dart';
import '../../../features/send/data/send_http.dart';
import '../../../features/send/logic/send_folder.dart';
import '../../../features/send/ui/send_outcome_message.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../services/desktop_notification_service.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../shared/apex_icons.dart';
import '../../../shared/device_card.dart';
import '../../../utils/path_name.dart';
import '../tv_apps_dialog.dart';
import '../tv_file_browser.dart';

/// A device's card on the TV: the shared [DeviceCard] by the remote, with
/// the TV's own browsers to pick what is sent. It shows the chat and does
/// not write in it (owner decision).
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
  /// The chat grows up to here, so the other cards stay on the screen.
  static const _chatHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = widget.device;
    final usable = widget.isActive && !device.versionMismatch;
    final chat = usable && device.isMdns;
    // One send at a time, like the phone card.
    final canSend = usable && !widget.isGloballyBusy;
    return DeviceCard(
      device: device,
      remote: true,
      autofocus: widget.autofocus,
      focusNode: widget.contentFocusNode,
      onBackToSidebar: widget.onBackToSidebar,
      usable: usable,
      chat: chat,
      // Offline first: it is what the device is now. The TV's line is
      // short, so another version says only that (owner decision).
      status: !widget.isActive
          ? l10n.deviceOffline
          : (device.versionMismatch ? l10n.versionDiffers : null),
      actions: canSend
          ? [
              // The TV browser picks several files, sent at once.
              (icon: ApexIcons.sendFilesNow, label: l10n.sendFilesNow, onTap: _sendFile),
              (icon: ApexIcons.sendApp, label: l10n.sendApp, onTap: _sendApp),
              (icon: ApexIcons.sendFolder, label: l10n.sendFolder, onTap: _sendFolder),
            ]
          : const [],
      // Nothing to send to an offline device, but the favourite stays in
      // reach, so an old device that never comes back can be removed.
      menu: () => _menu(l10n, chat),
      body: !usable
          ? null
          : (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isGloballyBusy)
                    DeviceCardNote(icon: ApexIcons.busy, text: l10n.chatTransferBusy),
                  if (widget.isGloballyBusy && chat) const SizedBox(height: 10),
                  if (chat)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: _chatHeight),
                      child: DeviceChatView(
                          store: ApexCore.instance.chat, device: device, canWrite: false),
                    ),
                ],
              ),
    );
  }

  List<DeviceMenuEntry> _menu(AppLocalizations l10n, bool chat) {
    final store = ApexCore.instance.chat;
    final pin = widget.isPinned ? widget.onUnpin : widget.onPin;
    return [
      if (pin != null)
        (
          icon: widget.isPinned ? ApexIcons.unfavorite : ApexIcons.favorite,
          label: widget.isPinned ? l10n.unpinDevice : l10n.pinDevice,
          onTap: pin,
          danger: false,
        ),
      if (chat && store.canBlock(widget.device.chatPeer))
        (icon: ApexIcons.block, label: l10n.chatBlock, onTap: _block, danger: true),
    ];
  }

  Future<void> _block() async {
    if (await confirmBlock(context, widget.device.name)) {
      ApexCore.instance.chat.block(widget.device.chatPeer);
    }
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
