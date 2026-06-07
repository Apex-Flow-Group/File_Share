import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';


class FilesTab extends StatefulWidget {
  final bool isSelectionMode;
  final Set<String> selectedFiles;
  final String sortBy;
  final bool sortAscending;
  final VoidCallback onExitSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onSaveSortPreference;
  final Function(String) onSortByChanged;
  final VoidCallback onToggleSortOrder;
  final Function(String) onToggleFileSelection;
  final Function(File) onOpenFile;
  final Function(File) onOpenFileLocation;
  final Function(String) onLongPress;
  final Future<List<FileSystemEntity>> Function() getReceivedFiles;

  const FilesTab({
    required this.isSelectionMode,
    required this.selectedFiles,
    required this.sortBy,
    required this.sortAscending,
    required this.onExitSelection,
    required this.onDeleteSelected,
    required this.onSelectAll,
    required this.onSaveSortPreference,
    required this.onSortByChanged,
    required this.onToggleSortOrder,
    required this.onToggleFileSelection,
    required this.onOpenFile,
    required this.onOpenFileLocation,
    required this.onLongPress,
    required this.getReceivedFiles,
    super.key,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> with AutomaticKeepAliveClientMixin {
  List<FileSystemEntity>? _files;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

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
        setState(() { _files = f; _isLoading = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (widget.isSelectionMode) _buildSelectionBar(),
          _buildSortBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFFFF9500);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]
              : [color.withValues(alpha: 0.12), color.withValues(alpha: 0.03)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                Text(
                  _files == null
                      ? '...'
                      : '${_files!.length} ${l10n.files}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Selection Bar ─────────────────────────────────────────────────────────

  Widget _buildSelectionBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: widget.onExitSelection,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${widget.selectedFiles.length} ${l10n.selected}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.select_all_rounded, size: 18),
            label: Text(l10n.selectAll),
            onPressed: widget.onSelectAll,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
            onPressed: widget.selectedFiles.isEmpty ? null : widget.onDeleteSelected,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ─── Sort Bar ──────────────────────────────────────────────────────────────

  Widget _buildSortBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(l10n.sortBy,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          const SizedBox(width: 8),
          _SortChip(
            value: widget.sortBy,
            options: {
              'date': l10n.date,
              'name': l10n.name,
              'size': l10n.size,
              'type': l10n.type,
            },
            onChanged: widget.onSortByChanged,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onToggleSortOrder,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onSaveSortPreference,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.save_rounded, size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(l10n.save,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── File List ─────────────────────────────────────────────────────────────

  Widget _buildList() {
    final l10n = AppLocalizations.of(context);

    if (_files == null || _files!.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 6),
                Text(
                  l10n.noFilesHint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sorted = _sort(_files!);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final file = File(sorted[i].path);
        final name = file.path.split('/').last;
        final isSelected = widget.selectedFiles.contains(file.path);
        return _FileTile(
          file: file,
          name: name,
          isSelected: isSelected,
          isSelectionMode: widget.isSelectionMode,
          onTap: () => widget.isSelectionMode
              ? widget.onToggleFileSelection(file.path)
              : widget.onOpenFile(file),
          onLongPress: () => widget.onLongPress(file.path),
          onOpenFile: () => widget.onOpenFile(file),
          onOpenLocation: () => widget.onOpenFileLocation(file),
        );
      },
    );
  }

  List<FileSystemEntity> _sort(List<FileSystemEntity> files) {
    final sorted = List<FileSystemEntity>.from(files);
    sorted.sort((a, b) {
      switch (widget.sortBy) {
        case 'name':
          return a.path.split('/').last.compareTo(b.path.split('/').last);
        case 'size':
          return File(a.path).lengthSync().compareTo(File(b.path).lengthSync());
        case 'type':
          return a.path.split('.').last.compareTo(b.path.split('.').last);
        default:
          return File(a.path).lastModifiedSync()
              .compareTo(File(b.path).lastModifiedSync());
      }
    });
    return widget.sortAscending ? sorted : sorted.reversed.toList();
  }
}

// ─── File Tile ─────────────────────────────────────────────────────────────────

class _FileTile extends StatelessWidget {
  final File file;
  final String name;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenLocation;

  const _FileTile({
    required this.file,
    required this.name,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenFile,
    required this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _fileColor(name);
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
              : null,
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // icon or checkbox
            isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  )
                : Container(
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
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(_fileIcon(name), color: Colors.white, size: 24),
                  ),
            const SizedBox(width: 12),
            // name + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Row(children: [
                    FutureBuilder<int>(
                      future: file.length(),
                      builder: (_, snap) => Text(
                        _fmt(snap.data ?? 0),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3, height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      file.parent.path.split('/').last,
                      style: TextStyle(
                        fontSize: 11,
                        color: iconColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            // menu
            if (!isSelectionMode)
              PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                position: PopupMenuPosition.over,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onOpenFile,
                    child: Row(children: [
                      const Icon(Icons.open_in_new_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.openFile),
                    ]),
                  ),
                  PopupMenuItem(
                    onTap: onOpenLocation,
                    child: Row(children: [
                      const Icon(Icons.folder_open_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.openFolder),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return Icons.image_rounded;
      case 'mp4': case 'avi': case 'mkv': case 'mov':
        return Icons.movie_rounded;
      case 'mp3': case 'wav': case 'flac': case 'm4a':
        return Icons.music_note_rounded;
      case 'zip': case 'rar': case '7z':
        return Icons.folder_zip_rounded;
      case 'apk': return Icons.android_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      case 'txt': return Icons.text_snippet_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return const Color(0xFFFF3B30);
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return const Color(0xFF007AFF);
      case 'mp4': case 'avi': case 'mkv': case 'mov':
        return const Color(0xFF5856D6);
      case 'mp3': case 'wav': case 'flac': case 'm4a':
        return const Color(0xFFFF2D55);
      case 'zip': case 'rar': case '7z':
        return const Color(0xFFFF9500);
      case 'apk': return const Color(0xFF34C759);
      case 'doc': case 'docx': return const Color(0xFF007AFF);
      case 'xls': case 'xlsx': return const Color(0xFF34C759);
      default: return const Color(0xFF8E8E93);
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

// ─── Sort Chip ─────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final Function(String) onChanged;

  const _SortChip({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
        top: false,
        child: _SortSheet(
          current: value,
          options: options,
          onChanged: onChanged,
        ),
      ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(options[value] ?? value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 14,
              color: Theme.of(context).colorScheme.onSurface),
        ]),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final String current;
  final Map<String, String> options;
  final Function(String) onChanged;

  const _SortSheet({
    required this.current,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ...options.entries.map((e) => ListTile(
            leading: Icon(
              current == e.key ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: current == e.key
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            title: Text(e.value,
                style: TextStyle(
                  fontWeight: current == e.key ? FontWeight.bold : FontWeight.normal,
                )),
            onTap: () { Navigator.pop(context); onChanged(e.key); },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )),
          const SizedBox(height: 8),
          SafeArea(top: false, child: SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 0 : 8)),
        ],
      ),
    );
  }
}
