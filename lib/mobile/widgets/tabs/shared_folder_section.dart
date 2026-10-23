// ignore_for_file: always_put_control_body_on_new_line

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/share_folder_service.dart';
import '../../../shared/apex_snackbar.dart';
import '../../../utils/file_utils.dart';

/// قسم المجلد المشترك — يُعرض داخل FilesTab على desktop فقط.
/// يعرض قائمة ملفات Share مع: فتح، حذف، رفع من القرص، فتح المجلد في Explorer.
class SharedFolderSection extends StatefulWidget {
  const SharedFolderSection({super.key});

  @override
  State<SharedFolderSection> createState() => _SharedFolderSectionState();
}

class _SharedFolderSectionState extends State<SharedFolderSection> {
  List<ShareFileInfo> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final files = await ShareFolderService.instance.listFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── رفع ملف من القرص إلى Share ─────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    int success = 0;
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null) continue;
      try {
        final file = File(path);
        await ShareFolderService.instance.saveUpload(
          rawName: picked.name,
          data: file.openRead(),
          contentLength: await file.length(),
        );
        success++;
      } catch (_) {}
    }
    if (mounted) {
      if (success > 0) {
        ApexSnackBar.success(context, l10n.uploadSuccess);
        await _load();
      } else {
        ApexSnackBar.error(context, l10n.uploadFailed);
      }
    }
  }

  // ─── حذف ملف ──────────────────────────────────────────────────────────────

  Future<void> _delete(ShareFileInfo file) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteFromShare),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ShareFolderService.instance.deleteFile(file.name);
      if (mounted) {
        ApexSnackBar.success(context, l10n.deletedFromShare);
        await _load();
      }
    } catch (_) {
      if (mounted) ApexSnackBar.error(context, l10n.uploadFailed);
    }
  }

  // ─── فتح ملف ──────────────────────────────────────────────────────────────

  Future<void> _openFile(ShareFileInfo file) async {
    try {
      final folder = await ShareFolderService.instance.getFolderPath();
      final path = '$folder${Platform.pathSeparator}${file.name}';
      await FileUtils.openFile(path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(
            context, AppLocalizations.of(context).openFileFailed);
      }
    }
  }

  // ─── فتح المجلد في Explorer ───────────────────────────────────────────────

  Future<void> _openInExplorer() async {
    try {
      await ShareFolderService.instance.openInExplorer();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF5856D6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── فاصل بصري
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                const Icon(Icons.folder_shared_rounded,
                    size: 14, color: Color(0xFF5856D6)),
                const SizedBox(width: 6),
                Text(
                  l10n.sharedFolder,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5856D6),
                  ),
                ),
              ]),
            ),
            const Expanded(child: Divider()),
          ]),
        ),

        // ─── Header: عنوان + أزرار
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_shared_rounded,
                        color: Color(0xFF5856D6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sharedFolder,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          _loading ? '...' : l10n.shareFileCount(_files.length),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // زر رفع
                  _HeaderButton(
                    icon: Icons.upload_rounded,
                    label: l10n.uploadToSharedFolder,
                    color: color,
                    isDark: isDark,
                    onTap: _pickAndUpload,
                  ),
                  const SizedBox(width: 8),
                  // زر فتح المجلد
                  _HeaderButton(
                    icon: Icons.open_in_new_rounded,
                    label: l10n.openInExplorer,
                    color: color,
                    isDark: isDark,
                    onTap: _openInExplorer,
                  ),
                ],
              ),
              // ─── قائمة الملفات
              const SizedBox(height: 12),
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _files.isEmpty
                      ? _buildEmpty(l10n, isDark)
                      : _buildFileList(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(AppLocalizations l10n, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded,
                size: 40,
                color: const Color(0xFF5856D6).withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(l10n.sharedFolderEmpty,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(l10n.sharedFolderEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(bool isDark) {
    return Column(
      children: _files
          .map((f) => _ShareFileTile(
                file: f,
                isDark: isDark,
                onOpen: () => _openFile(f),
                onDelete: () => _delete(f),
              ))
          .toList(),
    );
  }
}

// ─── زر صغير في Header ─────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─── صف ملف في Share ──────────────────────────────────────────────────────

class _ShareFileTile extends StatelessWidget {
  final ShareFileInfo file;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ShareFileTile({
    required this.file,
    required this.isDark,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5856D6);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Icon(
              FileUtils.getFileIcon(file.name),
              size: 20,
              color: color.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    FileUtils.formatSize(file.size),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.red),
              tooltip: AppLocalizations.of(context).delete,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
