import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../features/chat/ui/device_chat_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import 'tv_focusable_widgets.dart';

/// A device's chat on the TV: read only, closed with the remote.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              const SizedBox(height: 12),
              Flexible(
                child: DeviceChatView(
                    store: ApexCore.instance.chat, device: device, canWrite: false),
              ),
              const SizedBox(height: 16),
              TVDialogButton(
                label: l10n.close,
                color: Colors.blue,
                autofocus: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
