import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/clipboard_monitor_service.dart';
import '../../../shared/framed_capsule_input.dart';
import '../../../utils/path_name.dart';
import '../../clipboard/ui/clipboard_label.dart';

/// A file in the message box, sent with the next send.
class ComposerFile {
  ComposerFile(this.path, {this.fromClipboard = false});

  final String path;

  /// A copied picture or file: once sent, the copy is no longer offered.
  final bool fromClipboard;

  String get name => fileNameOf(path);

  bool get isImage {
    final dot = name.lastIndexOf('.');
    return dot > 0 && _images.contains(name.substring(dot + 1).toLowerCase());
  }

  static const _images = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
}

/// The files on top of the message box, as in chat apps: a picture as
/// itself, any other file by its name; a cross takes an added one out.
class ComposerTiles extends StatelessWidget {
  const ComposerTiles({required this.files, required this.onRemove, super.key});

  final List<ComposerFile> files;
  final void Function(ComposerFile) onRemove;

  static const size = 88.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _Tile(file: files[i], onRemove: onRemove),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.file, required this.onRemove});

  final ComposerFile file;
  final void Function(ComposerFile) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = FramedCapsuleColors.of(context);
    final face = file.isImage
        ? Image.file(File(file.path),
            width: ComposerTiles.size,
            height: ComposerTiles.size,
            fit: BoxFit.cover,
            cacheWidth: (ComposerTiles.size * 2).round(),
            errorBuilder: (_, __, ___) => _named(c))
        : _named(c);
    final tile = ClipRRect(borderRadius: BorderRadius.circular(16), child: face);
    return Stack(children: [
      tile,
      PositionedDirectional(
        top: 4,
        end: 4,
        child: Semantics(
          container: true,
          button: true,
          label: l10n.chatRemoveFile(file.name),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onRemove(file),
            child: CircleAvatar(
                radius: 13,
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
          ),
        ),
      ),
    ]);
  }

  Widget _named(FramedCapsuleColors c) => Container(
        width: ComposerTiles.size,
        height: ComposerTiles.size,
        color: c.circle,
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.insert_drive_file_rounded, color: c.onCircle),
          const SizedBox(height: 4),
          Text(file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text, fontSize: 11)),
        ]),
      );
}

/// What was just copied on a computer, floating above the message box with
/// a button that offers to add it (owner decision): a picture as itself,
/// text by its length only, since it may be a password.
class CopiedSuggestion extends StatelessWidget {
  const CopiedSuggestion({required this.item, required this.onAdd, required this.onDismiss, super.key});

  final ClipboardItem item;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = FramedCapsuleColors.of(context);
    final label = clipboardLabel(l10n, item);
    final picture = item.type == ClipboardItemType.image && item.paths.isNotEmpty;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: c.capsule,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), side: BorderSide(color: c.border)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: picture
                  ? Image.file(File(item.paths.first), width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 112)
                  : Container(
                      width: 56,
                      height: 56,
                      color: c.circle,
                      child: Icon(
                          item.type == ClipboardItemType.text
                              ? Icons.notes_rounded
                              : Icons.insert_drive_file_rounded,
                          color: c.onCircle)),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(label,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.chatAdd),
            ),
            IconButton(
              tooltip: l10n.close,
              onPressed: onDismiss,
              icon: Icon(Icons.close_rounded, color: c.hint, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}
