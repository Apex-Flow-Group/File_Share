import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/file_ui_utils.dart';

/// A single file item tile for the files list.
class FileTile extends StatelessWidget {
  final File file;
  final String name;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenLocation;

  const FileTile({
    required this.file,
    required this.name,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenFile,
    required this.onOpenLocation,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = FileUiUtils.fileColor(name);
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
              : isDark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 1.5)
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
                    child: Icon(FileUiUtils.fileIcon(name),
                        color: Colors.white, size: 24),
                  ),
            const SizedBox(width: 12),
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
                        FileUiUtils.formatFileSize(snap.data ?? 0),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
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
}
