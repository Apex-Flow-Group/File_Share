import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/apex_core.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../services/desktop_notification_service.dart';
import '../../services/folder_zip_service.dart';
import '../../services/transfer_progress_service.dart';
import '../../shared/apex_snackbar.dart';
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

    setSending();
    try {
      final ok = await ApexCore.instance.sendFiles(paths, device);
      if (mounted) {
        _showSnack(
          ok
              ? AppLocalizations.of(context).fileSentSuccess
              : AppLocalizations.of(context).fileSendFailed,
          ok,
        );
      }
      final label = paths.length == 1
          ? paths.first.split('/').last
          : '${paths.length} files';
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
          final paths = selectedApps.map((a) => a.file.path).toList();
          final names = selectedApps.map((a) => '${a.name}.apk').toList();

          bool ok;
          if (selectedApps.length == 1) {
            ok = await ApexCore.instance
                .sendFileWithName(paths.first, names.first, device);
          } else {
            final files = <String>[];
            for (int i = 0; i < selectedApps.length; i++) {
              final src = selectedApps[i].file;
              final dir = src.parent.path;
              final dest = File('$dir/${names[i]}');
              if (dest.path != src.path) {
                await src.copy(dest.path);
                files.add(dest.path);
              } else {
                files.add(src.path);
              }
            }
            ok = await ApexCore.instance.sendFiles(files, device);
            for (int i = 0; i < files.length; i++) {
              if (files[i] != selectedApps[i].file.path) {
                try {
                  await File(files[i]).delete();
                } catch (_) {}
              }
            }
          }

          if (!mounted) {
            return;
          }
          _showSnack(
            ok
                ? AppLocalizations.of(context).appSent
                : AppLocalizations.of(context).sendFailed,
            ok,
          );
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
    String? zipPath;
    try {
      zipPath = await FolderZipService.zipFolder(folderPath);
      final folderName = folderPath.split(Platform.pathSeparator).last;

      final ok = await ApexCore.instance
          .sendFileWithName(zipPath, '$folderName.zip', device);
      if (mounted) {
        _showSnack(
          ok
              ? AppLocalizations.of(context).folderSent
              : AppLocalizations.of(context).sendFailed,
          ok,
        );
      }
      final label = '$folderName.zip';
      if (ok) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
      }
    } finally {
      if (zipPath != null) {
        await FolderZipService.cleanupTemp(zipPath);
      }
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }

  void _showSnack(String msg, bool ok) {
    if (!mounted) {
      return;
    }
    ApexSnackBar.result(context, ok: ok, successMessage: msg, failMessage: msg);
  }
}
