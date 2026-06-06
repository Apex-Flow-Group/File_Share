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
  final List<FocusNode> _fileFocusNodes = [];
  final _fileOpsService = FileOperationsService();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await widget.getReceivedFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _updateFocusNodes();
        if (_fileFocusNodes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fileFocusNodes[0].requestFocus();
          });
        }
      });
    }
  }

  void _updateFocusNodes() {
    for (var node in _fileFocusNodes) {
      node.dispose();
    }
    _fileFocusNodes.clear();
    if (_files != null) {
      for (int i = 0; i < _files!.length; i++) {
        _fileFocusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    for (var node in _fileFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.files, style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 32),
                onPressed: _loadFiles,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildFilesList(l10n)),
        ],
      ),
    );
  }

  Widget _buildFilesList(AppLocalizations l10n) {
    if (_files == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 100, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(l10n.noFiles, style: const TextStyle(fontSize: 24)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _files!.length,
      itemBuilder: (context, index) {
        final file = File(_files![index].path);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFileCard(file, index, l10n),
        );
      },
    );
  }

  Widget _buildFileCard(File file, int index, AppLocalizations l10n) {
    final fileName = file.path.split('/').last;
    
    return Focus(
      focusNode: _fileFocusNodes[index],
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && index > 0) {
            _fileFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && index < _files!.length - 1) {
            _fileFocusNodes[index + 1].requestFocus();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.space) {
            _showFileOptions(file, l10n);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.delete) {
            _deleteFile(file, l10n);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            decoration: BoxDecoration(
              border: hasFocus 
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                : Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(_getFileIcon(fileName), size: 40, color: Theme.of(context).colorScheme.primary),
              title: Text(fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: FutureBuilder<int>(
                future: file.length(),
                builder: (context, snapshot) {
                  final size = snapshot.data ?? 0;
                  return Text(_formatFileSize(size), style: const TextStyle(fontSize: 16));
                },
              ),
              trailing: const Icon(Icons.more_vert, size: 32),
              onTap: () => _showFileOptions(file, l10n),
            ),
          );
        },
      ),
    );
  }

  void _showFileOptions(File file, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.path.split('/').last, style: const TextStyle(fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionButton(
              icon: Icons.open_in_new,
              label: l10n.openFile,
              onPressed: () {
                Navigator.pop(context);
                _openFile(file);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.folder_open,
              label: l10n.openFolder,
              onPressed: () {
                Navigator.pop(context);
                _openFileLocation(file);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.delete,
              label: l10n.delete,
              color: Colors.red,
              onPressed: () {
                Navigator.pop(context);
                _deleteFile(file, l10n);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: color,
          foregroundColor: color != null ? Colors.white : null,
        ),
      ),
    );
  }

  Future<void> _openFile(File file) async {
    try {
      await _fileOpsService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        _showMessage('❌ ${AppLocalizations.of(context).openFileFailed}');
      }
    }
  }

  Future<void> _openFileLocation(File file) async {
    try {
      await _fileOpsService.openFileLocation(file.path);
    } catch (e) {
      if (mounted) {
        _showMessage('❌ ${AppLocalizations.of(context).openLocationFailed}');
      }
    }
  }

  Future<void> _deleteFile(File file, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteFiles, style: const TextStyle(fontSize: 20)),
        content: Text('${l10n.deleteConfirmation} ${file.path.split('/').last}?', style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(fontSize: 18, color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _fileOpsService.deleteFiles({file.path}, deleteFromFolder: true);
      if (mounted) {
        _showMessage('✅ ${l10n.filesDeletedCount}');
        await _loadFiles();
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))),
    );
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
