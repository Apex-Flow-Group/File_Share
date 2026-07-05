import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/apex_core.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/file_operations_service.dart';
import '../../../shared/apex_snackbar.dart';
import '../tv_focusable_widgets.dart';
import 'tv_file_tile.dart';

class TVFilesTab extends StatefulWidget {
  final Future<List<FileSystemEntity>> Function() getReceivedFiles;
  final VoidCallback? onBackToSidebar;
  final FocusNode? contentFocusNode;
  const TVFilesTab({
    required this.getReceivedFiles,
    this.onBackToSidebar,
    this.contentFocusNode,
    super.key,
  });

  @override
  State<TVFilesTab> createState() => _TVFilesTabState();
}

class _TVFilesTabState extends State<TVFilesTab> {
  List<FileSystemEntity>? _files;
  bool _isLoading = false;
  final _fileOpsService = FileOperationsService();
  StreamSubscription? _fileReceivedSub;

  @override
  void initState() {
    super.initState();
    _load();
    _fileReceivedSub = ApexCore.instance.fileReceivedStream.listen((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _fileReceivedSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final f = await widget.getReceivedFiles();
      if (mounted) {
        setState(() {
          _files = f;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFFFF9500);

    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ─── Header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.05)
                    ]
                  : [
                      color.withValues(alpha: 0.12),
                      color.withValues(alpha: 0.03)
                    ],
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.folder_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.files,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      _files == null
                          ? '...'
                          : '${_files!.length} ${l10n.files}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ]),
            ),
            _TVFocusableRefreshButton(onTap: _load),
          ]),
        ),
        // ─── List ────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildList(l10n, isDark),
        ),
      ]),
    );
  }

  Widget _buildList(AppLocalizations l10n, bool isDark) {
    if (_files == null || _files!.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 64, color: Color(0xFFFF9500)),
          ),
          const SizedBox(height: 20),
          Text(l10n.noFiles,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(l10n.noFilesHint,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: _files!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final file = File(_files![i].path);
        final name = file.path.split(Platform.pathSeparator).last;
        return TVFileTile(
          file: file,
          name: name,
          isDark: isDark,
          autofocus: i == 0,
          contentFocusNode: i == 0 ? widget.contentFocusNode : null,
          onOpen: () => _openFile(file),
          onOpenLocation: () => _openLocation(file),
          onDelete: () => _deleteFile(file, l10n),
          onBackToSidebar: widget.onBackToSidebar,
        );
      },
    );
  }

  Future<void> _openFile(File file) async {
    try {
      await _fileOpsService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(
            context, '${AppLocalizations.of(context).openFileFailed}: $e');
      }
    }
  }

  Future<void> _openLocation(File file) async {
    try {
      await _fileOpsService.openFileLocation(file.path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(
            context, '${AppLocalizations.of(context).openLocationFailed}: $e');
      }
    }
  }

  Future<void> _deleteFile(File file, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _TVDeleteConfirmDialog(
        fileName: file.path.split(Platform.pathSeparator).last,
        l10n: l10n,
      ),
    );
    if (ok == true && mounted) {
      await _fileOpsService.deleteFiles({file.path}, deleteFromFolder: true);
      await _load();
    }
  }
}

// ─── TV Delete Confirm Dialog ─────────────────────────────────────────────────

class _TVDeleteConfirmDialog extends StatelessWidget {
  final String fileName;
  final AppLocalizations l10n;
  const _TVDeleteConfirmDialog({
    required this.fileName,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(l10n.deleteFiles,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('${l10n.deleteConfirmation} $fileName?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TVDialogButton(
                    label: l10n.cancel,
                    color: Colors.grey,
                    autofocus: true,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TVDialogButton(
                    label: l10n.delete,
                    color: Colors.red,
                    autofocus: false,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TV Focusable Refresh Button ──────────────────────────────────────────────

class _TVFocusableRefreshButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TVFocusableRefreshButton({required this.onTap});

  @override
  State<_TVFocusableRefreshButton> createState() =>
      _TVFocusableRefreshButtonState();
}

class _TVFocusableRefreshButtonState extends State<_TVFocusableRefreshButton> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF9500);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: hasFocus ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: hasFocus ? Border.all(color: color, width: 2) : null,
            ),
            child: const Icon(Icons.refresh_rounded, color: color, size: 22),
          ),
        );
      }),
    );
  }
}
