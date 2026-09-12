import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/apex_core.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../mobile/screens/apps_selection_screen.dart';
import '../../../mobile/widgets/connection_widget.dart';
import '../../../models/device.dart';
import '../../../services/desktop_notification_service.dart';
import '../../../services/folder_zip_service.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../shared/apex_snackbar.dart';
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
          child: ConnectionWidget(
            device: widget.device,
            isActive: widget.isActive,
            isPinned: widget.isPinned,
            onPin: widget.onPin,
            onUnpin: widget.onUnpin,
            isGloballyBusy: widget.isGloballyBusy,
          ),
        );
      }),
    );
  }

  void _showSendOptions(BuildContext context) {
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
      ),
    );
  }

  Future<void> _sendFile() async {
    final paths = await showTVFileBrowser(context);
    if (paths == null || paths.isEmpty || !mounted) {
      return;
    }

    final ok = await ApexCore.instance.sendFiles(paths, widget.device);
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ApexSnackBar.result(context,
          ok: ok,
          successMessage: l10n.fileSentSuccess,
          failMessage: l10n.fileSendFailed);
    }
    final label = paths.length == 1
        ? paths.first.split('/').last
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
    await AppsSelectionSheet.show(
      context,
      onAppsSelected: (selectedApps) async {
        if (!mounted || selectedApps.isEmpty) {
          return;
        }
        bool ok;
        if (selectedApps.length == 1) {
          ok = await ApexCore.instance.sendFileWithName(
              selectedApps.first.file.path,
              '${selectedApps.first.name}.apk',
              widget.device);
        } else {
          final paths = selectedApps.map((a) => a.file.path).toList();
          ok = await ApexCore.instance.sendFiles(paths, widget.device);
        }
        if (!mounted) {
          return;
        }
        final l10n = AppLocalizations.of(context);
        ApexSnackBar.result(context,
            ok: ok, successMessage: l10n.appSent, failMessage: l10n.sendFailed);
        TransferProgressService().clearProgress();
      },
    );
  }

  Future<void> _sendFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null || !mounted) {
      return;
    }

    String? zipPath;
    try {
      zipPath = await FolderZipService.zipFolder(folderPath);
      final folderName = folderPath.split(Platform.pathSeparator).last;

      final ok = await ApexCore.instance
          .sendFileWithName(zipPath, '$folderName.zip', widget.device);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ApexSnackBar.result(context,
            ok: ok,
            successMessage: l10n.folderSent,
            failMessage: l10n.sendFailed);
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
    }
  }
}

// ─── TV Send Options Dialog ───────────────────────────────────────────────────

class _TVSendOptionsDialog extends StatelessWidget {
  final String title;
  final bool isDark;
  final Color color;
  final AppLocalizations l10n;
  final VoidCallback onSendFile;
  final VoidCallback onSendApp;
  final VoidCallback onSendFolder;

  const _TVSendOptionsDialog({
    required this.title,
    required this.isDark,
    required this.color,
    required this.l10n,
    required this.onSendFile,
    required this.onSendApp,
    required this.onSendFolder,
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
            TVDialogOption(
              icon: Icons.folder_open_rounded,
              label: l10n.sendFile,
              color: color,
              autofocus: true,
              onTap: onSendFile,
            ),
            const SizedBox(height: 8),
            if (Platform.isAndroid)
              TVDialogOption(
                icon: Icons.android_rounded,
                label: l10n.sendApp,
                color: const Color(0xFF34C759),
                autofocus: false,
                onTap: onSendApp,
              )
            else
              TVDialogOption(
                icon: Icons.folder_zip_rounded,
                label: l10n.sendFolder,
                color: const Color(0xFF5856D6),
                autofocus: false,
                onTap: onSendFolder,
              ),
          ],
        ),
      ),
    );
  }
}
