import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../utils/path_name.dart';

const _storageRoot = '/storage/emulated/0';

typedef FolderLister = Future<List<FileSystemEntity>> Function(Directory dir);

Future<List<FileSystemEntity>> _list(Directory dir) => dir.list().toList();

/// يعرض file browser مدمج للتلفاز بدون الحاجة لأي تطبيق خارجي
/// يُرجع قائمة بمسارات الملفات المختارة
Future<List<String>?> showTVFileBrowser(BuildContext context,
    {String root = _storageRoot, FolderLister list = _list}) async {
  final picked = await showDialog<Object>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _TVFileBrowser(root: root, pickFolder: false, list: list),
  );
  return picked as List<String>?;
}

/// The same browser, choosing the folder that is open. [root] itself cannot
/// be chosen: it is the whole storage.
Future<String?> showTVFolderBrowser(BuildContext context,
    {String root = _storageRoot, FolderLister list = _list}) async {
  final picked = await showDialog<Object>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _TVFileBrowser(root: root, pickFolder: true, list: list),
  );
  return picked as String?;
}

class _TVFileBrowser extends StatefulWidget {
  final String root;
  final bool pickFolder;
  final FolderLister list;

  const _TVFileBrowser({required this.root, required this.pickFolder, required this.list});

  @override
  State<_TVFileBrowser> createState() => _TVFileBrowserState();
}

class _TVFileBrowserState extends State<_TVFileBrowser> {
  late final List<String> _pathStack = [widget.root];
  List<FileSystemEntity> _items = [];
  final Set<String> _selected = {};
  bool _loading = true;

  final _scrollCtrl = ScrollController();
  final List<FocusNode> _focusNodes = [];
  final List<GlobalKey> _itemKeys = [];
  final _mainButton = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadDir(_pathStack.last);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _mainButton.dispose();
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // Paths come with a backslash on Windows, where the tests also run.
  static String _nameOf(String path) => fileNameOf(path);

  Future<void> _loadDir(String path) async {
    setState(() {
      _loading = true;
    });
    try {
      final dir = Directory(path);
      final raw = await widget.list(dir);
      raw.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir && !bDir) {
          return -1;
        }
        if (!aDir && bDir) {
          return 1;
        }
        return _nameOf(a.path)
            .toLowerCase()
            .compareTo(_nameOf(b.path).toLowerCase());
      });
      // أضف ".." إذا مش في الجذر
      final showBack = _pathStack.length > 1;
      if (mounted) {
        // تأكد من وجود FocusNodes كافية
        final needed = raw.length + (showBack ? 1 : 0);
        while (_focusNodes.length < needed) {
          _focusNodes.add(FocusNode());
        }
        while (_itemKeys.length < needed) {
          _itemKeys.add(GlobalKey());
        }
        setState(() {
          _items = raw;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_focusNodes.isNotEmpty) {
            _focusNodes[0].requestFocus();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openDir(String path) {
    _pathStack.add(path);
    _loadDir(path);
  }

  void _goBack() {
    if (_pathStack.length > 1) {
      _pathStack.removeLast();
      _loadDir(_pathStack.last);
    } else {
      Navigator.of(context).pop(null);
    }
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  bool get _canConfirm => widget.pickFolder ? _pathStack.length > 1 : _selected.isNotEmpty;

  void _confirm() {
    if (!_canConfirm) {
      return;
    }
    Navigator.of(context).pop(widget.pickFolder ? _pathStack.last : _selected.toList());
  }

  // At the root the last part of /storage/emulated/0 would read "0".
  String get _currentDir => _pathStack.length == 1
      ? AppLocalizations.of(context).storageLabel
      : _nameOf(_pathStack.last);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;
    final showBack = _pathStack.length > 1;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // قائمة العناصر مع ".." في البداية
    final displayItems = <_BrowserItem>[];
    if (showBack) {
      displayItems.add(const _BrowserItem(isBack: true, path: '', name: '..'));
    }
    for (final e in _items) {
      final name = _nameOf(e.path);
      if (name.startsWith('.')) {
        continue; // إخفاء الملفات المخفية
      }
      displayItems.add(_BrowserItem(
        isBack: false,
        path: e.path,
        name: name,
        isDir: e is Directory,
      ));
    }

    // The remote's Back arrives as a route pop: inside a folder it goes up
    // one level instead of closing the browser.
    return PopScope(
      canPop: !showBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Dialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Column(
        children: [
          // ─── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
            ),
            child: Row(children: [
              Icon(Icons.folder_rounded, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _currentDir,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selected.length} محدد',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),

          // ─── List ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : displayItems.isEmpty
                    ? Center(
                        child: Text(
                          'مجلد فارغ',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        itemCount: displayItems.length,
                        itemBuilder: (ctx, i) {
                          final item = displayItems[i];
                          final isSelected = _selected.contains(item.path);
                          while (_focusNodes.length <= i) {
                            _focusNodes.add(FocusNode());
                            _itemKeys.add(GlobalKey());
                          }
                          return _BrowserTile(
                            key: _itemKeys[i],
                            // Files are shown so the folder's content is known, not picked.
                            dimmed: widget.pickFolder && !item.isDir && !item.isBack,
                            item: item,
                            isSelected: isSelected,
                            focusNode: _focusNodes[i],
                            isDark: isDark,
                            color: color,
                            isRtl: isRtl,
                            onKey: (event) {
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.ignored;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                final next = i + 1;
                                if (next >= displayItems.length) {
                                  // The list leads down to the main button.
                                  _mainButton.requestFocus();
                                } else {
                                  _focusNodes[next].requestFocus();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final ctx = _itemKeys[next].currentContext;
                                    if (ctx != null) {
                                      Scrollable.ensureVisible(ctx,
                                          alignment: 0.7,
                                          duration: const Duration(milliseconds: 150));
                                    }
                                  });
                                }
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                final prev = i - 1;
                                if (prev >= 0) {
                                  _focusNodes[prev].requestFocus();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final ctx = _itemKeys[prev].currentContext;
                                    if (ctx != null) {
                                      Scrollable.ensureVisible(ctx,
                                          alignment: 0.3,
                                          duration: const Duration(milliseconds: 150));
                                    }
                                  });
                                }
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.select ||
                                  event.logicalKey == LogicalKeyboardKey.enter) {
                                if (item.isBack) {
                                  _goBack();
                                } else if (item.isDir) {
                                  _openDir(item.path);
                                } else if (!widget.pickFolder) {
                                  _toggleSelect(item.path);
                                }
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.goBack ||
                                  event.logicalKey == LogicalKeyboardKey.escape) {
                                _goBack();
                                return KeyEventResult.handled;
                              }
                              // زر أيمن/يسار — confirm إذا في محدد
                              final confirmKey = isRtl
                                  ? LogicalKeyboardKey.arrowLeft
                                  : LogicalKeyboardKey.arrowRight;
                              if (event.logicalKey == confirmKey && _canConfirm) {
                                _confirm();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            onTap: () {
                              if (item.isBack) {
                                _goBack();
                              } else if (item.isDir) {
                                _openDir(item.path);
                              } else if (!widget.pickFolder) {
                                _toggleSelect(item.path);
                              }
                            },
                          );
                        },
                      ),
          ),

          // ─── Footer ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
            ),
            child: Row(children: [
              Expanded(
                child: _FooterButton(
                  label: AppLocalizations.of(context).cancel,
                  color: Colors.grey,
                  onTap: () => Navigator.of(context).pop(null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FooterButton(
                  focusNode: _mainButton,
                  label: widget.pickFolder
                      ? _canConfirm
                          ? AppLocalizations.of(context).sendThisFolder
                          : AppLocalizations.of(context).pickFolder
                      : _selected.isEmpty
                          ? AppLocalizations.of(context).pickFile
                          : AppLocalizations.of(context).sendCount(_selected.length),
                  color: _canConfirm ? color : Colors.grey,
                  onTap: _canConfirm ? _confirm : null,
                ),
              ),
            ]),
          ),
        ],
      ),
    ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _BrowserTile extends StatelessWidget {
  final _BrowserItem item;
  final bool dimmed;
  final bool isSelected;
  final FocusNode focusNode;
  final bool isDark;
  final Color color;
  final bool isRtl;
  final KeyEventResult Function(KeyEvent) onKey;
  final VoidCallback onTap;

  const _BrowserTile({
    required this.item, required this.dimmed, required this.isSelected, required this.focusNode, required this.isDark, required this.color, required this.isRtl, required this.onKey, required this.onTap, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (_, event) => onKey(event),
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: dimmed ? 0.45 : 1,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.18)
                  : hasFocus
                      ? color.withValues(alpha: 0.09)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: hasFocus || isSelected
                  ? Border.all(
                      color: color.withValues(alpha: hasFocus ? 0.7 : 0.3),
                      width: hasFocus ? 2 : 1,
                    )
                  : null,
            ),
            child: Row(children: [
              // أيقونة
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _iconColor(item).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconData(item), size: 20, color: _iconColor(item)),
              ),
              const SizedBox(width: 12),
              // اسم
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected || hasFocus ? color : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // check
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
              if (item.isDir && !item.isBack)
                Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
            ]),
          ),
          ),
        );
      }),
    );
  }

  IconData _iconData(_BrowserItem item) {
    if (item.isBack) {
      return Icons.arrow_back_rounded;
    }
    if (item.isDir) {
      return Icons.folder_rounded;
    }
    final ext = item.name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
      return Icons.movie_rounded;
    }
    if (['mp3', 'wav', 'flac', 'm4a'].contains(ext)) {
      return Icons.music_note_rounded;
    }
    if (['pdf'].contains(ext)) {
      return Icons.picture_as_pdf_rounded;
    }
    if (['apk'].contains(ext)) {
      return Icons.android_rounded;
    }
    if (['zip', 'rar', '7z'].contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor(_BrowserItem item) {
    if (item.isBack) {
      return Colors.grey;
    }
    if (item.isDir) {
      return const Color(0xFFFF9500);
    }
    final ext = item.name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return const Color(0xFF007AFF);
    }
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
      return const Color(0xFF5856D6);
    }
    if (['mp3', 'wav', 'flac', 'm4a'].contains(ext)) {
      return const Color(0xFFFF2D55);
    }
    if (['pdf'].contains(ext)) {
      return const Color(0xFFFF3B30);
    }
    if (['apk'].contains(ext)) {
      return const Color(0xFF34C759);
    }
    if (['zip', 'rar', '7z'].contains(ext)) {
      return const Color(0xFFFF9500);
    }
    return const Color(0xFF8E8E93);
  }
}

// ─── Footer Button ────────────────────────────────────────────────────────────

class _FooterButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  const _FooterButton({required this.label, required this.color, this.onTap, this.focusNode});

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  final _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;

  @override
  void dispose() {
    _ownFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        final enabled = widget.onTap != null;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: enabled
                  ? (hasFocus ? widget.color : widget.color.withValues(alpha: 0.12))
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: hasFocus
                  ? Border.all(color: widget.color, width: 2)
                  : Border.all(color: widget.color.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? (hasFocus ? Colors.white : widget.color)
                      : Colors.grey,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _BrowserItem {
  final bool isBack;
  final String path;
  final String name;
  final bool isDir;

  const _BrowserItem({
    required this.isBack,
    required this.path,
    required this.name,
    this.isDir = false,
  });
}
