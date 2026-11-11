
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../features/send/data/send_http.dart';
import '../../features/send/logic/send_folder.dart';
import '../../features/send/ui/send_outcome_message.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../services/desktop_notification_service.dart';
import '../../services/transfer_progress_service.dart';
import '../../utils/path_name.dart';
import '../screens/apps_selection_screen.dart';

/// Mixin that encapsulates file/app/folder send actions for ConnectionWidget.
mixin ConnectionSendActions<T extends StatefulWidget> on State<T> {
  Device get device;
  void setSending();
  void setIdle();

  Future<void> sendFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final paths =
        result.files.where((f) => f.path != null).map((f) => f.path!).toList();

    final l10n = AppLocalizations.of(context);
    setSending();
    try {
      final outcome = await ApexCore.instance.sendFiles(paths, device);
      final ok = outcome == SendOutcome.sent;
      if (mounted) {
        showSendOutcome(context, outcome,
            sent: AppLocalizations.of(context).fileSentSuccess,
            failed: AppLocalizations.of(context).fileSendFailed);
      }
      // Read before the awaits below, while the screen is still there.
      final label = paths.length == 1
          ? fileNameOf(paths.first)
          : l10n.clipboardFileCount(paths.length);
      if (ok) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }

  Future<void> sendApp() async {
    if (!mounted) {
      return;
    }
    await AppsSelectionSheet.show(
      context,
      onAppsSelected: (selectedApps) async {
        if (!mounted || selectedApps.isEmpty) {
          return;
        }
        setSending();
        try {
          final outcome = await ApexCore.instance.sendNamedFiles(
              [for (final a in selectedApps) (path: a.file.path, name: '${a.name}.apk')], device);

          if (!mounted) {
            return;
          }
          showSendOutcome(context, outcome,
              sent: AppLocalizations.of(context).appSent,
              failed: AppLocalizations.of(context).sendFailed);
        } finally {
          TransferProgressService().clearProgress();
          if (mounted) {
            setIdle();
          }
        }
      },
    );
  }

  Future<void> sendFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null || !mounted) {
      return;
    }

    setSending();
    try {
      final (:outcome, :label) = await sendFolderZipped(folderPath, device);
      if (mounted) {
        showSendOutcome(context, outcome,
            sent: AppLocalizations.of(context).folderSent,
            failed: AppLocalizations.of(context).sendFailed);
      }
      if (outcome == SendOutcome.sent) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }
}
