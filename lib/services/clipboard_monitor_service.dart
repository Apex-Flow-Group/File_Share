import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum ClipboardItemType { image, files, text }

class ClipboardItem {
  final List<String> paths;
  final ClipboardItemType type;
  /// معاينة النص — مملوء فقط عندما type == text
  final String? textPreview;

  const ClipboardItem({
    required this.paths,
    required this.type,
    this.textPreview,
  });

  /// اسم العرض: للنص يعرض المعاينة، للصورة اسم الملف، للملفات الاسم الأول
  String get displayName {
    if (type == ClipboardItemType.text && textPreview != null) {
      return textPreview!;
    }
    if (paths.isEmpty) {
      return '';
    }
    final name = paths.first.replaceAll('\\', '/').split('/').last;
    return name;
  }

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
/// يعمل على Windows فقط — على باقي المنصات يبقى صامتاً.
class ClipboardMonitorService {
  static final ClipboardMonitorService _instance =
      ClipboardMonitorService._();
  static ClipboardMonitorService get instance => _instance;
  ClipboardMonitorService._();

  static const _channel = MethodChannel('com.apex.core/clipboard');

  final _controller = StreamController<ClipboardItem?>.broadcast();

  Stream<ClipboardItem?> get stream => _controller.stream;

  // مسارات الملفات المؤقتة للصور — لحذفها بعد الإرسال
  final List<String> _tempImagePaths = [];

  static bool get _isWindows => !kIsWeb && Platform.isWindows;

  // ─── تهيئة ────────────────────────────────────────────────────────────────

  void initialize() {
    if (!_isWindows) {
      return;
    }
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onClipboardChanged') {
      return;
    }

    final args = call.arguments as Map?;
    if (args == null) {
      return;
    }

    final type = args['type'] as String?;
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

    final itemType = type == 'image'
        ? ClipboardItemType.image
        : type == 'text'
            ? ClipboardItemType.text
            : ClipboardItemType.files;

    final textPreview = args['textPreview'] as String?;

    if (itemType == ClipboardItemType.image) {
      _tempImagePaths.add(existing.first);
    }
    if (itemType == ClipboardItemType.text) {
      _tempImagePaths.add(existing.first); // نستخدم نفس قائمة التنظيف
    }

    _controller.add(ClipboardItem(
      paths: existing,
      type: itemType,
      textPreview: textPreview,
    ));
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
