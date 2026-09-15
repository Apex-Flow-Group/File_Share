// ignore_for_file: always_put_control_body_on_new_line

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../services/share_folder_service.dart';
import '../../shared/apex_snackbar.dart';
import '../../utils/file_utils.dart';

/// شاشة تصفح المجلد المشترك لجهاز PC آخر على الشبكة.
/// مُصمَّمة لتتناسب مع سطح المكتب — no standard AppBar.
class ShareBrowserScreen extends StatefulWidget {
  final Device device;

  const ShareBrowserScreen({required this.device, super.key});

  @override
  State<ShareBrowserScreen> createState() => _ShareBrowserScreenState();
}

class _ShareBrowserScreenState extends State<ShareBrowserScreen> {
  List<ShareFileInfo> _files = [];
  bool _loading = true;
  String? _error;

  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─── جلب قائمة الملفات ────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = Uri.http(
        '${widget.device.ip}:${widget.device.port}',
        '/share',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(url);
      final res = await req.close();
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List<dynamic>;
      final files = list
          .map((e) => ShareFileInfo(
                name: e['name'] as String,
                size: (e['size'] as num).toInt(),
                modified: DateTime.tryParse(e['modified'] as String? ?? '') ??
                    DateTime.now(),
                mime: e['mime'] as String?,
              ))
          .toList();
      client.close();
      if (mounted) {
        setState(() {
          _files = files;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '${AppLocalizations.of(context).shareNetworkError}\n$e';
        });
      }
    }
  }

  // ─── تنزيل ملف ────────────────────────────────────────────────────────────

  Future<void> _download(ShareFileInfo file) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _progress[file.name] = 0.0);
    try {
      final url = Uri.http(
        '${widget.device.ip}:${widget.device.port}',
        '/share/file',
        {'name': file.name},
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(url);
      final res = await req.close();

      if (res.statusCode == 404) throw Exception('Not found');
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final tmpDir = await getTemporaryDirectory();
      final tmpPath = '${tmpDir.path}/${file.name}';
      final sink = File(tmpPath).openWrite();
      int received = 0;
      final total = file.size;

      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress[file.name] = received / total);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();

      String finalPath;
      if (Platform.isAndroid) {
        finalPath = tmpPath;
      } else {
        final destDir = await _getDownloadDir();
        finalPath = '$destDir/${file.name}';
        try {
          await File(tmpPath).rename(finalPath);
        } catch (_) {
          await File(tmpPath).copy(finalPath);
          await File(tmpPath).delete().catchError((_) => File(tmpPath));
        }
      }

      if (mounted) {
        setState(() => _progress.remove(file.name));
        ApexSnackBar.success(context, l10n.uploadSuccess);
        await FileUtils.openFile(finalPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _progress.remove(file.name));
        ApexSnackBar.error(context, l10n.downloadFailed);
      }
    }
  }

  // ─── رفع ملف ──────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    final file = File(picked.path!);
    final size = await file.length();
    final name = picked.name;

    setState(() => _progress[name] = 0.0);
    try {
      final url = Uri.http(
        '${widget.device.ip}:${widget.device.port}',
        '/share/upload',
        {'name': name, 'from': Platform.localHostname},
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30)
        ..idleTimeout = Duration(seconds: ((size / (100 * 1024)) + 60).ceil());

      final req = await client.postUrl(url);
      req.headers.set('Content-Length', size.toString());

      int sent = 0;
      await for (final chunk in file.openRead()) {
        req.add(chunk);
        sent += chunk.length;
        if (size > 0 && mounted) {
          setState(() => _progress[name] = sent / size);
        }
      }
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      client.close();

      if (mounted) {
        setState(() => _progress.remove(name));
        if (body['success'] == true) {
          ApexSnackBar.success(context, l10n.uploadSuccess);
          await _load();
        } else {
          ApexSnackBar.error(context, l10n.uploadFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _progress.remove(name));
        ApexSnackBar.error(context, l10n.uploadFailed);
      }
    }
  }

  Future<String> _getDownloadDir() async {
    if (Platform.isAndroid) {
      return (await getTemporaryDirectory()).path;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/ApexShare/Downloads');
    await dir.create(recursive: true);
    return dir.path;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF5856D6);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header يشبه باقي شاشات التطبيق
            _buildHeader(l10n, isDark, color, isDesktop),
            // ─── المحتوى
            Expanded(
              child: isDesktop
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _buildContent(l10n, isDark, color),
                      ),
                    )
                  : _buildContent(l10n, isDark, color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      AppLocalizations l10n, bool isDark, Color color, bool isDesktop) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 16, isDesktop ? 24 : 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.04),
                ]
              : [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          // زر رجوع
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // أيقونة المجلد
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.folder_shared_rounded,
                color: Color(0xFF5856D6), size: 22),
          ),
          const SizedBox(width: 14),
          // العنوان
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sharedFolder,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.device.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${widget.device.ip}:${widget.device.port}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // عدد الملفات
          if (!_loading && _error == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.shareFileCount(_files.length),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          const SizedBox(width: 10),
          // زر رفع
          _HeaderIconButton(
            icon: Icons.upload_rounded,
            tooltip: l10n.uploadToSharedFolder,
            color: color,
            isDark: isDark,
            enabled: _progress.isEmpty,
            onTap: _upload,
          ),
          const SizedBox(width: 8),
          // زر تحديث
          _HeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: l10n.restartingSystem,
            color: color,
            isDark: isDark,
            enabled: !_loading,
            onTap: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n, bool isDark, Color color) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 56, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.shareNetworkError,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!.split('\n').last,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.restartingSystem),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.folder_open_rounded,
                  size: 56, color: color.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(l10n.sharedFolderEmpty,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(l10n.sharedFolderEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final file = _files[i];
          final inProgress = _progress.containsKey(file.name);
          return _FileTile(
            file: file,
            isDark: isDark,
            progress: _progress[file.name],
            inProgress: inProgress,
            onDownload: inProgress ? null : () => _download(file),
          );
        },
      ),
    );
  }
}

// ─── Header Icon Button ──────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── File Tile ────────────────────────────────────────────────────────────────

class _FileTile extends StatelessWidget {
  final ShareFileInfo file;
  final bool isDark;
  final double? progress;
  final bool inProgress;
  final VoidCallback? onDownload;

  const _FileTile({
    required this.file,
    required this.isDark,
    required this.inProgress,
    this.progress,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const color = Color(0xFF5856D6);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // أيقونة الملف
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    FileUtils.getFileIcon(file.name),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // اسم الملف + الحجم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        FileUtils.formatSize(file.size),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // زر تنزيل
                inProgress
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: color,
                        ),
                      )
                    : Tooltip(
                        message: l10n.downloadFromShare,
                        child: GestureDetector(
                          onTap: onDownload,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: color,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          // شريط التقدم
          if (inProgress && progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5856D6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
