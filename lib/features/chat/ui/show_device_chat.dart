import 'package:flutter/material.dart';

import '../../../core/apex_core.dart';
import '../../../models/device.dart';
import '../../../shared/apex_bottom_sheet.dart';
import 'device_chat_view.dart';

/// Opens [device]'s chat in a bottom sheet (phone and computer).
Future<void> showDeviceChat(BuildContext context, Device device) {
  return ApexBottomSheet.show<void>(
    context,
    isScrollControlled: true,
    child: Builder(builder: (context) {
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
              Text(device.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Flexible(child: DeviceChatView(store: ApexCore.instance.chat, device: device)),
            ],
          ),
        ),
      );
    }),
  );
}
