import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../features/chat/logic/chat_key.dart';
import '../../features/chat/ui/device_chat_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import 'tv_focusable_widgets.dart';

/// A device's chat on the TV: read only, closed with the remote. Blocking is
/// still here, since a device the TV accepted could otherwise keep writing.
class TVChatDialog extends StatelessWidget {
  const TVChatDialog({required this.device, super.key});

  final Device device;

  /// One chat at a time: a message from a second device waits in its chat
  /// instead of opening a dialog over the first.
  static bool _showing = false;

  static Future<void> show(BuildContext context, Device device) async {
    if (_showing) {
      return;
    }
    _showing = true;
    try {
      await showDialog<void>(context: context, builder: (_) => TVChatDialog(device: device));
    } finally {
      _showing = false;
    }
  }

  Future<void> _block(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.chatBlockQuestion(device.name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Text(l10n.chatBlockDetail, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(children: [
                  // The focus starts on Cancel, so a stray OK never blocks.
                  Expanded(
                    child: TVDialogButton(
                        label: l10n.cancel,
                        color: Colors.blue,
                        autofocus: true,
                        onTap: () => Navigator.pop(ctx, false)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TVDialogButton(
                        label: l10n.chatBlock,
                        color: Colors.red,
                        autofocus: false,
                        onTap: () => Navigator.pop(ctx, true)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    if (yes == true) {
      ApexCore.instance.chat.block(device.chatPeer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = ApexCore.instance.chat;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(device.ip,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 12),
              Flexible(
                child: DeviceChatView(store: store, device: device, canWrite: false),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) => Row(children: [
                  Expanded(
                    child: TVDialogButton(
                      label: l10n.close,
                      color: Colors.blue,
                      autofocus: true,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  if (store.canBlock(device.chatPeer)) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TVDialogButton(
                        label: l10n.chatBlock,
                        color: Colors.red,
                        autofocus: false,
                        onTap: () => _block(context),
                      ),
                    ),
                  ] else if (store.isBlocked(device.chatPeer)) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TVDialogButton(
                        label: l10n.chatUnblock,
                        color: Colors.grey,
                        autofocus: false,
                        onTap: () => store.unblock(device.chatPeer),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
