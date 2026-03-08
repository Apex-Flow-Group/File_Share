import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
    required this.isSelectionMode, required this.selectedFiles, required this.sortBy, required this.sortAscending, required this.onExitSelection, required this.onDeleteSelected, required this.onSelectAll, required this.onSaveSortPreference, required this.onSortByChanged, required this.onToggleSortOrder, required this.onToggleFileSelection, required this.onOpenFile, required this.onOpenFileLocation, required this.onLongPress, required this.getReceivedFiles, super.key,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> with AutomaticKeepAliveClientMixin {
  List<FileSystemEntity>? _cachedFiles;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (_isLoading) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final files = await widget.getReceivedFiles();
      if (mounted) {
        setState(() {
          _cachedFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (widget.isSelectionMode) _buildSelectionBar(context),
        _buildSortBar(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFiles,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildFilesList(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFilesList(BuildContext context) {
    if (_cachedFiles == null || _cachedFiles!.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 100,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).noFiles,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final files = _sortFiles(
      _cachedFiles!,
      sortBy: widget.sortBy,
      ascending: widget.sortAscending,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final file = File(files[index].path);
        final fileName = file.path.split('/').last;
        final isSelected = widget.selectedFiles.contains(file.path);

        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: widget.isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) => widget.onToggleFileSelection(file.path),
                  )
                : Icon(_getFileIcon(fileName),
                    size: 40,
                    color: Theme.of(context).colorScheme.primary),
            title: Text(fileName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<int>(
                  future: file.length(),
                  builder: (context, snapshot) {
                    final size = snapshot.data ?? 0;
                    return Text(_formatFileSize(size));
                  },
                ),
                Text(
                  file.parent.path.split('/').last,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            trailing: widget.isSelectionMode
                ? null
                : PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).openFile),
                          ],
                        ),
                        onTap: () => widget.onOpenFile(file),
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).openFolder),
                          ],
                        ),
                        onTap: () => widget.onOpenFileLocation(file),
                      ),
                    ],
                  ),
            onTap: widget.isSelectionMode
                ? () => widget.onToggleFileSelection(file.path)
                : () => widget.onOpenFile(file),
            onLongPress: () => widget.onLongPress(file.path),
          ),
        );
      },
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onExitSelection,
          ),
          Text('${widget.selectedFiles.length} ${AppLocalizations.of(context).selected}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.select_all, size: 20),
            label: Text(AppLocalizations.of(context).selectAll),
            onPressed: widget.onSelectAll,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: widget.selectedFiles.isEmpty ? null : widget.onDeleteSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(AppLocalizations.of(context).sortBy,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: widget.sortBy,
            items: [
              DropdownMenuItem(
                  value: 'date', child: Text(AppLocalizations.of(context).date)),
              DropdownMenuItem(
                  value: 'size', child: Text(AppLocalizations.of(context).size)),
              DropdownMenuItem(
                  value: 'type', child: Text(AppLocalizations.of(context).type)),
              DropdownMenuItem(
                  value: 'name', child: Text(AppLocalizations.of(context).name)),
            ],
            onChanged: (val) => widget.onSortByChanged(val!),
          ),
          IconButton(
            icon: Icon(widget.sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: widget.onToggleSortOrder,
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: Text(AppLocalizations.of(context).save),
            onPressed: widget.onSaveSortPreference,
          ),
        ],
      ),
    );
  }


  List<FileSystemEntity> _sortFiles(List<FileSystemEntity> files, {required String sortBy, required bool ascending}) {
    final sorted = List<FileSystemEntity>.from(files);
    sorted.sort((a, b) {
      switch (sortBy) {
        case 'name':
          return a.path.split('/').last.compareTo(b.path.split('/').last);
        case 'size':
          final sizeA = File(a.path).lengthSync();
          final sizeB = File(b.path).lengthSync();
          return sizeA.compareTo(sizeB);
        case 'type':
          final extA = a.path.split('.').last;
          final extB = b.path.split('.').last;
          return extA.compareTo(extB);
        case 'date':
        default:
          return File(a.path).lastModifiedSync().compareTo(File(b.path).lastModifiedSync());
      }
    });
    return ascending ? sorted : sorted.reversed.toList();
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image;
      case 'mp4': case 'avi': case 'mkv': return Icons.video_file;
      case 'mp3': case 'wav': case 'flac': return Icons.audio_file;
      case 'zip': case 'rar': case '7z': return Icons.folder_zip;
      case 'apk': return Icons.android;
      default: return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}
