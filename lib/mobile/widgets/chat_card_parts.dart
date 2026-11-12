import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../features/chat/ui/chat_attach.dart';
import '../../features/chat/ui/device_chat_view.dart';
import '../../models/device.dart';
import '../../services/clipboard_monitor_service.dart';
import '../../shared/framed_capsule_input.dart';

/// The chat inside an opened card: the messages and the message box.
class ChatCardPanel extends StatelessWidget {
  const ChatCardPanel({
    required this.device,
    this.initialText,
    this.initialFiles = const [],
    this.copied,
    this.onCopiedUsed,
    this.extras = const [],
    super.key,
  });

  final Device device;
  final List<CapsuleAction> extras;
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
        extras: extras,
      ),
    );
  }
}
