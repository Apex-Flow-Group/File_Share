import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/file_ui_utils.dart';
import '../tv_focusable_widgets.dart';

/// A focusable file tile for TV interfaces with remote support.
class TVFileTile extends StatefulWidget {
  final File file;
  final String name;
  final bool isDark;
  final bool autofocus;
  final VoidCallback onOpen;
  final VoidCallback onOpenLocation;
  final VoidCallback onDelete;
  final VoidCallback? onBackToSidebar;
  final FocusNode? contentFocusNode;

  const TVFileTile({
    required this.file,
    required this.name,
    required this.isDark,
    required this.autofocus,
    required this.onOpen,
    required this.onOpenLocation,
    required this.onDelete,
    this.onBackToSidebar,
    this.contentFocusNode,
    super.key,
  });

  @override
  State<TVFileTile> createState() => _TVFileTileState();
}

class _TVFileTileState extends State<TVFileTile> {
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
    final iconColor = FileUiUtils.fileColor(widget.name);
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
          _showOptions(context);
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
        return GestureDetector(
          onTap: () => _showOptions(context),
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
                child: Icon(FileUiUtils.fileIcon(widget.name),
                    color: Colors.white, size: 24),
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
                          FileUiUtils.formatFileSize(snap.data ?? 0),
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

  void _showOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              TVDialogOption(
                icon: Icons.open_in_new_rounded,
                label: l10n.openFile,
                color: color,
                autofocus: true,
                onTap: () {
                  Navigator.pop(dialogContext);
                  widget.onOpen();
                },
              ),
              const SizedBox(height: 8),
              TVDialogOption(
                icon: Icons.folder_open_rounded,
                label: l10n.openFolder,
                color: color,
                autofocus: false,
                onTap: () {
                  Navigator.pop(dialogContext);
                  widget.onOpenLocation();
                },
              ),
              const SizedBox(height: 8),
              TVDialogOption(
                icon: Icons.delete_rounded,
                label: l10n.delete,
                color: Colors.red,
                autofocus: false,
                onTap: () {
                  Navigator.pop(dialogContext);
                  widget.onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
