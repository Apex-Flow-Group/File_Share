import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/apex_apps_loader.dart';
import 'tv_focusable_widgets.dart';

typedef PickedApp = ({File file, String name});

/// Picks installed apps to send with the remote. A dialog, not the phone's
/// bottom sheet: the remote cannot reach a bottom sheet reliably.
/// Returns null when closed with Back.
Future<List<PickedApp>?> showTVAppsDialog(
  BuildContext context, {
  Future<List<ApexAppInfo>> Function() load = ApexAppsLoader.getInstalledApps,
}) =>
    showDialog<List<PickedApp>>(
      context: context,
      builder: (_) => _TVAppsDialog(load: load),
    );

class _TVAppsDialog extends StatefulWidget {
  final Future<List<ApexAppInfo>> Function() load;

  const _TVAppsDialog({required this.load});

  @override
  State<_TVAppsDialog> createState() => _TVAppsDialogState();
}

class _TVAppsDialogState extends State<_TVAppsDialog> {
  List<ApexAppInfo>? _apps;
  bool _showSystemApps = false;
  final Set<String> _selected = {};
  final _firstApp = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.load().then((apps) {
      if (!mounted) {
        return;
      }
      setState(() => _apps = apps);
      WidgetsBinding.instance.addPostFrameCallback((_) => _firstApp.requestFocus());
    });
  }

  @override
  void dispose() {
    _firstApp.dispose();
    super.dispose();
  }

  List<ApexAppInfo> get _visible =>
      (_apps ?? const []).where((a) => _showSystemApps || !a.isSystemApp).toList();

  void _toggle(ApexAppInfo app) => setState(() {
        if (!_selected.remove(app.packageName)) {
          _selected.add(app.packageName);
        }
      });

  void _send() {
    final picked = (_apps ?? const <ApexAppInfo>[])
        .where((a) => _selected.contains(a.packageName))
        .map<PickedApp>((a) => (file: File(a.apkPath), name: a.name))
        .toList();
    if (picked.isNotEmpty) {
      Navigator.of(context).pop(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const green = Color(0xFF34C759);
    final apps = _visible;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.android_rounded, color: green, size: 22),
              const SizedBox(width: 10),
              Text(l10n.installedApps,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            _FocusRow(
              onSelect: () => setState(() => _showSystemApps = !_showSystemApps),
              child: Row(children: [
                Expanded(child: Text(l10n.systemApps)),
                ExcludeFocus(
                  child: Switch(
                    value: _showSystemApps,
                    onChanged: (v) => setState(() => _showSystemApps = v),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _apps == null
                  ? const Center(child: CircularProgressIndicator())
                  : apps.isEmpty
                      ? Center(child: Text(l10n.noApps))
                      : ListView.builder(
                          itemCount: apps.length,
                          itemBuilder: (_, i) {
                            final app = apps[i];
                            final picked = _selected.contains(app.packageName);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _FocusRow(
                                focusNode: i == 0 ? _firstApp : null,
                                onSelect: () => _toggle(app),
                                child: Row(children: [
                                  Image.memory(app.icon, width: 36, height: 36,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.android_rounded, size: 36)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(app.name,
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Icon(
                                    picked
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: picked ? green : Colors.grey,
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 10),
            TVDialogButton(
              label: _selected.isEmpty ? l10n.pickApp : l10n.sendCount(_selected.length),
              color: _selected.isEmpty ? Colors.grey : green,
              autofocus: false,
              onTap: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// A row the remote can focus; OK runs [onSelect].
class _FocusRow extends StatelessWidget {
  final Widget child;
  final VoidCallback onSelect;
  final FocusNode? focusNode;

  const _FocusRow({required this.child, required this.onSelect, this.focusNode});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasFocus ? color.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hasFocus ? color : Colors.grey.withValues(alpha: 0.15),
                  width: hasFocus ? 2 : 1),
            ),
            child: child,
          ),
        );
      }),
    );
  }
}
