import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/apex_bottom_sheet.dart';
import '../../../shared/apex_snackbar.dart';
import '../delete_files_sheet.dart';
import 'file_tile.dart';

class FilesTab extends StatefulWidget {
  final bool isSelectionMode;
  final Set<String> selectedFiles;
  final String sortBy;
  final bool sortAscending;
  final VoidCallback onExitSelection;
  final Future<int> Function(bool deleteFromDevice) onDeleteSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onSaveSortPreference;
  final Function(String) onSortByChanged;
  final VoidCallback onToggleSortOrder;
  final Function(String) onToggleFileSelection;
  final Function(File) onOpenFile;
  final Function(File) onOpenFileLocation;
  final Function(String) onLongPress;
  final Future<List<FileSystemEntity>> Function() getReceivedFiles;
  final ValueNotifier<int>? refreshNotifier;

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
    this.refreshNotifier,
    super.key,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab>
    with AutomaticKeepAliveClientMixin {
  List<FileSystemEntity>? _files;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    widget.refreshNotifier?.addListener(_onRefreshNotified);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshNotified);
    super.dispose();
  }

  void _onRefreshNotified() => _load();

  /// ظٹظ…ظƒظ† ط§ط³طھط¯ط¹ط§ط،ظ‡ط§ ظ…ظ† ط§ظ„ط®ط§ط±ط¬ ط¹ط¨ط± GlobalKey ظ„طھط­ط¯ظٹط« ط§ظ„ظ‚ط§ط¦ظ…ط©
  Future<void> refresh() => _load();

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

  Future<void> _showDeleteSheet() async {
    final result = await DeleteFilesSheet.show(
      context,
      fileCount: widget.selectedFiles.length,
    );
    if (result != null && mounted) {
      final count = await widget.onDeleteSelected(result.deleteFromDevice);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ApexSnackBar.success(context, '$count ${l10n.filesDeletedCount}');
        await _load();
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child:
                widget.isSelectionMode ? _buildSelectionBar() : _buildSortBar(),
          ),
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

  // â”€â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                  _files == null ? '...' : '${_files!.length} ${l10n.files}',
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

  // â”€â”€â”€ Selection Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSelectionBar() {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      key: const ValueKey('selection_bar'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onExitSelection,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close_rounded, size: 16, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.selectedFiles.length} ${l10n.selected}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onSelectAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.select_all_rounded, size: 14, color: color),
                const SizedBox(width: 4),
                Text(l10n.selectAll,
                    style: TextStyle(fontSize: 12, color: color)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.selectedFiles.isEmpty ? null : _showDeleteSheet,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.selectedFiles.isEmpty
                    ? Colors.grey.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_rounded,
                  size: 16,
                  color:
                      widget.selectedFiles.isEmpty ? Colors.grey : Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Sort Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSortBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const ValueKey('sort_bar'),
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
                Icon(Icons.save_rounded,
                    size: 14,
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

  // â”€â”€â”€ File List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildList() {
    final l10n = AppLocalizations.of(context);
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16;

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
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final file = File(sorted[i].path);
        final name = file.path.split('/').last;
        final isSelected = widget.selectedFiles.contains(file.path);
        return FileTile(
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
      try {
        switch (widget.sortBy) {
          case 'name':
            return a.path
                .split('/')
                .last
                .toLowerCase()
                .compareTo(b.path.split('/').last.toLowerCase());
          case 'size':
            return File(a.path)
                .lengthSync()
                .compareTo(File(b.path).lengthSync());
          case 'type':
            return a.path
                .split('.')
                .last
                .toLowerCase()
                .compareTo(b.path.split('.').last.toLowerCase());
          default:
            return File(a.path)
                .lastModifiedSync()
                .compareTo(File(b.path).lastModifiedSync());
        }
      } catch (_) {
        return 0;
      }
    });
    return widget.sortAscending ? sorted : sorted.reversed.toList();
  }
}

// â”€â”€â”€ Sort Chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      onTap: () => ApexBottomSheet.showPicker(
        context: context,
        title: AppLocalizations.of(context).sortBy,
        items: options.entries
            .map((e) => PickerItem(
                  label: e.value,
                  value: e.key,
                  icon: _sortIcon(e.key),
                ))
            .toList(),
        currentValue: value,
        onSelected: (v) => onChanged(v as String),
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
          Icon(Icons.expand_more_rounded,
              size: 14, color: Theme.of(context).colorScheme.onSurface),
        ]),
      ),
    );
  }

  IconData _sortIcon(String key) {
    switch (key) {
      case 'name':
        return Icons.sort_by_alpha_rounded;
      case 'size':
        return Icons.storage_rounded;
      case 'type':
        return Icons.category_rounded;
      default:
        return Icons.calendar_today_rounded;
    }
  }
}
