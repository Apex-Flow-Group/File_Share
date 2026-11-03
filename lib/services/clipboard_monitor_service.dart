import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/private_temp.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum ClipboardItemType { image, files, text }

class ClipboardItem {
  final List<String> paths;
  final ClipboardItemType type;

  /// The copied text, kept in memory only. Empty [paths] when type == text.
  final String? text;

  const ClipboardItem({
    required this.paths,
    required this.type,
    this.text,
  });

  /// حجم إجمالي لكل الملفات (بايت)
  Future<int> get totalSize async {
    int total = 0;
    for (final p in paths) {
      try {
        total += await File(p).length();
      } catch (_) {}
    }
    return total;
  }

  /// امتداد الملف لتحديد الأيقونة واللون
  String get extensionHint {
    if (type == ClipboardItemType.image) {
      return 'image';
    }
    if (type == ClipboardItemType.text) {
      return 'txt';
    }
    final ext = paths.first.split('.').last.toLowerCase();
    return ext;
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// يستمع لأحداث الـ clipboard القادمة من C++ عبر MethodChannel.
/// يُطلق stream بـ ClipboardItem جديد عند كل تغيير.
/// Windows and Linux only. The runners watch nothing until [setEnabled]
/// sends "start": copied text includes passwords, so watching is the
/// user's choice and off by default.
class ClipboardMonitorService {
  static final ClipboardMonitorService _instance =
      ClipboardMonitorService._();
  static ClipboardMonitorService get instance => _instance;
  ClipboardMonitorService._();

  @visibleForTesting
  ClipboardMonitorService.forTesting();

  static const _channel = MethodChannel('com.apex.core/clipboard');

  final _controller = StreamController<ClipboardItem?>.broadcast();

  Stream<ClipboardItem?> get stream => _controller.stream;

  // مسارات الملفات المؤقتة للصور — لحذفها بعد الإرسال
  final List<String> _tempImagePaths = [];

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  // ─── تهيئة ────────────────────────────────────────────────────────────────

  void initialize() {
    if (!_isDesktop) {
      return;
    }
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  bool _enabled = false;

  Future<void> setEnabled(bool on) async {
    if (!_isDesktop || on == _enabled) {
      return;
    }
    _enabled = on;
    await _channel.invokeMethod<void>(on ? 'start' : 'stop');
    if (!on) {
      clearItem();
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onClipboardChanged' || !_enabled) {
      return;
    }

    final args = call.arguments as Map?;
    if (args == null) {
      return;
    }

    final type = args['type'] as String?;
    if (type == 'text') {
      final text = args['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        _controller.add(ClipboardItem(paths: const [], type: ClipboardItemType.text, text: text));
      }
      return;
    }
    final rawPaths = args['paths'];

    if (type == null || rawPaths == null) {
      return;
    }

    final paths = (rawPaths as List).cast<String>();
    if (paths.isEmpty) {
      return;
    }

    // تحقق من وجود الملفات فعلاً
    final existing = <String>[];
    for (final p in paths) {
      if (await File(p).exists()) {
        existing.add(p);
      }
    }
    if (existing.isEmpty) {
      return;
    }

    final itemType =
        type == 'image' ? ClipboardItemType.image : ClipboardItemType.files;

    if (itemType == ClipboardItemType.image) {
      _tempImagePaths.add(existing.first);
    }

    _controller.add(ClipboardItem(paths: existing, type: itemType));
  }

  /// Runs [send] with file paths for [item]. Text exists as a file only for
  /// the length of the send, in a fresh owner-only folder under [tempRoot]
  /// (the system temp folder by default), removed whatever the outcome.
  Future<T> withSendableFiles<T>(
      ClipboardItem item, Future<T> Function(List<String> paths) send,
      {Directory? tempRoot}) async {
    final text = item.text;
    if (item.type != ClipboardItemType.text || text == null) {
      return send(item.paths);
    }
    final work = await createPrivateTemp(tempRoot ?? Directory.systemTemp, 'apex_clip_');
    try {
      final file = File('${work.path}${Platform.pathSeparator}clipboard_${_stamp()}.txt');
      await file.writeAsString(text, flush: true);
      return await send([file.path]);
    } finally {
      await work.delete(recursive: true);
    }
  }

  static String _stamp() {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  // ─── بعد الإرسال — نظّف الملفات المؤقتة ─────────────────────────────────

  Future<void> cleanupTempImages() async {
    for (final p in List<String>.from(_tempImagePaths)) {
      try {
        final f = File(p);
        if (await f.exists()) {
          await f.delete();
        }
        _tempImagePaths.remove(p);
      } catch (_) {}
    }
  }

  /// أبلغ الـ stream بأنه لم يعد هناك clipboard item معلق
  void clearItem() {
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
