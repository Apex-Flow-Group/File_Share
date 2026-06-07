import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/file_operations_service.dart';

class TVFilesTab extends StatefulWidget {
  final Future<List<FileSystemEntity>> Function() getReceivedFiles;
  const TVFilesTab({required this.getReceivedFiles, super.key});

  @override
  State<TVFilesTab> createState() => _TVFilesTabState();
}

class _TVFilesTabState extends State<TVFilesTab> {
  List<FileSystemEntity>? _files;
  bool _isLoading = false;
  final _fileOpsService = FileOperationsService();

  @override
  void initState() {
    super.initState();
    _load();
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
        // ─── Header ────────────────────────────────────────────────────
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
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              style: IconButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
              ),
            ),
          ]),
        ),
        // ─── List ──────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(l10n, isDark),
          ),
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
        return _TVFileTile(
          file: file,
          name: name,
          isDark: isDark,
          onOpen: () => _openFile(file),
          onOpenLocation: () => _openLocation(file),
          onDelete: () => _deleteFile(file, l10n),
        );
      },
    );
  }

  Future<void> _openFile(File file) async {
    try {
      await _fileOpsService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).openFileFailed}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _openLocation(File file) async {
    try {
      await _fileOpsService.openFileLocation(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${AppLocalizations.of(context).openLocationFailed}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteFile(File file, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteFiles),
        content: Text(
            '${l10n.deleteConfirmation} ${file.path.split(Platform.pathSeparator).last}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _fileOpsService.deleteFiles({file.path}, deleteFromFolder: true);
      await _load();
    }
  }
}

// ─── TV File Tile ─────────────────────────────────────────────────────────────

class _TVFileTile extends StatefulWidget {
  final File file;
  final String name;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onOpenLocation;
  final VoidCallback onDelete;

  const _TVFileTile({
    required this.file,
    required this.name,
    required this.isDark,
    required this.onOpen,
    required this.onOpenLocation,
    required this.onDelete,
  });

  @override
  State<_TVFileTile> createState() => _TVFileTileState();
}

class _TVFileTileState extends State<_TVFileTile> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _fileColor(widget.name);
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          _showOptions(context, l10n);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => _showOptions(context, l10n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: hasFocus ? Border.all(color: color, width: 2.5) : null,
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.2), blurRadius: 12)
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: widget.isDark ? 0.25 : 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      )
                    ],
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [iconColor, iconColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: iconColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child:
                    Icon(_fileIcon(widget.name), color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 3),
                      FutureBuilder<int>(
                        future: widget.file.length(),
                        builder: (_, snap) => Text(
                          _fmt(snap.data ?? 0),
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ]),
              ),
              Icon(Icons.more_vert_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ]),
          ),
        );
      }),
    );
  }

  void _showOptions(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(l10n.openFile),
              onTap: () {
                Navigator.pop(context);
                widget.onOpen();
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: Text(l10n.openFolder),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenLocation();
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title:
                  Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Icons.movie_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
        return Icons.music_note_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFFF3B30);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return const Color(0xFF007AFF);
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return const Color(0xFF5856D6);
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
        return const Color(0xFFFF2D55);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFFF9500);
      case 'apk':
        return const Color(0xFF34C759);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  String _fmt(int b) {
    if (b < 1024) {
      return '$b B';
    }
    if (b < 1024 * 1024) {
      return '${(b / 1024).toStringAsFixed(1)} KB';
    }
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}
