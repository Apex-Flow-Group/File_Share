import 'package:flutter/material.dart';

import '../../../core/apex_core.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../shared/apex_bottom_sheet.dart';
import 'confirm_block.dart';
import 'device_chat_view.dart';

/// Opens [device]'s chat in a bottom sheet (phone and computer).
Future<void> showDeviceChat(BuildContext context, Device device) {
  final store = ApexCore.instance.chat;
  return ApexBottomSheet.show<void>(
    context,
    isScrollControlled: true,
    child: Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      final media = MediaQuery.of(context);
      final keyboard = media.viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: (media.size.height - keyboard) * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        // The chat is bound to this address; a name alone can be claimed.
                        Text(device.ip,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: store,
                    builder: (context, _) => store.canBlock(device.ip)
                        ? TextButton.icon(
                            onPressed: () async {
                              if (await confirmBlock(context, device.name)) {
                                store.block(device.ip);
                              }
                            },
                            icon: const Icon(Icons.block_rounded, size: 18, color: Colors.red),
                            label: Text(l10n.chatBlock, style: const TextStyle(color: Colors.red)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(child: DeviceChatView(store: store, device: device)),
            ],
          ),
        ),
      );
    }),
  );
}
