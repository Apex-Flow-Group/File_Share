// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helper ───────────────────────────────────────────────────────────────────

/// يُنشئ ShareFolderService يشير إلى مجلد مؤقت بدلاً من Documents
class _TestService {
  late Directory shareDir;

  Future<ShareFolderService> init() async {
    shareDir = await Directory.systemTemp.createTemp('apex_share_test_');
    // نعيد توجيه resolveSafeFile / listFiles عبر subclass مؤقت بمجلد اختبار
    return _OverrideService(shareDir.path);
  }

  Future<void> tearDown() async {
    if (await shareDir.exists()) {
      await shareDir.delete(recursive: true);
    }
  }
}

class _OverrideService extends ShareFolderService {
  final String _path;
  _OverrideService(this._path) : super.forTesting();

  @override
  Future<String> getFolderPath() async => _path;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _TestService helper;
  late ShareFolderService svc;

  setUp(() async {
    helper = _TestService();
    svc = await helper.init();
  });

  tearDown(() => helper.tearDown());

  // ── Path Jail ──────────────────────────────────────────────────────────────

  group('path jail', () {
    test('يرفض ../ traversal', () async {
      expect(await svc.resolveSafeFile('../etc/passwd'), isNull);
      expect(await svc.resolveSafeFile('../../secret'), isNull);
      expect(await svc.resolveSafeFile('..'), isNull);
    });

    test('يرفض مسارات مطلقة Unix', () async {
      expect(await svc.resolveSafeFile('/etc/passwd'), isNull);
      expect(await svc.resolveSafeFile('/tmp/evil'), isNull);
    });

    test('يرفض null bytes', () async {
      expect(await svc.resolveSafeFile('file\x00.txt'), isNull);
    });

    test('يرفض فواصل مسار مضمّنة', () async {
      expect(await svc.resolveSafeFile('sub/file.txt'), isNull);
      expect(await svc.resolveSafeFile('sub\\file.txt'), isNull);
    });

    test('يرفض اسماً فارغاً بعد التنظيف', () async {
      expect(await svc.resolveSafeFile('   '), isNull);
      expect(await svc.resolveSafeFile(''), isNull);
    });

    test('يقبل اسماً عادياً ويُعيد مساراً داخل Share', () async {
      final path = await svc.resolveSafeFile('document.pdf');
      expect(path, isNotNull);
      expect(path!.startsWith(helper.shareDir.absolute.path), isTrue);
    });

    test('يُنظّف الأحرف غير المسموح بها بدل الرفض', () async {
      final path = await svc.resolveSafeFile('my<file>.txt');
      expect(path, isNotNull); // الاسم يُنظَّف ولا يُرفض
    });
  });

  // ── listFiles ──────────────────────────────────────────────────────────────

  group('listFiles', () {
    test('يُعيد قائمة فارغة إذا كان المجلد فارغاً', () async {
      final files = await svc.listFiles();
      expect(files, isEmpty);
    });

    test('يرى الملفات داخل Share فقط', () async {
      // أضف ملفين في المجلد
      await File('${helper.shareDir.path}/a.txt').writeAsString('A');
      await File('${helper.shareDir.path}/b.txt').writeAsString('BB');

      final files = await svc.listFiles();
      expect(files.map((f) => f.name), containsAll(['a.txt', 'b.txt']));
      expect(files.length, equals(2));
    });

    test('لا يرى المجلدات الفرعية', () async {
      await Directory('${helper.shareDir.path}/subdir').create();
      await File('${helper.shareDir.path}/file.txt').writeAsString('x');

      final files = await svc.listFiles();
      expect(files.length, equals(1));
      expect(files.first.name, equals('file.txt'));
    });

    test('يُعيد الحجم الصحيح', () async {
      const content = 'hello world';
      await File('${helper.shareDir.path}/size.txt').writeAsString(content);

      final files = await svc.listFiles();
      expect(files.first.size, equals(content.length));
    });
  });

  // ── saveUpload + تصادم الأسماء ─────────────────────────────────────────────

  group('saveUpload', () {
    test('يحفظ ملفاً جديداً بالمحتوى الصحيح', () async {
      const content = 'apex shared content';
      final stream =
          Stream<List<int>>.value(content.codeUnits.map((c) => c).toList());

      final path = await svc.saveUpload(
        rawName: 'test.txt',
        data: stream,
        contentLength: content.length,
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsStringSync(), equals(content));
    });

    test('يُعيد تسمية عند تصادم الأسماء: name (1).ext', () async {
      final data1 = Stream<List<int>>.value([1, 2, 3]);
      final data2 = Stream<List<int>>.value([4, 5, 6]);

      final path1 = await svc.saveUpload(
          rawName: 'file.txt', data: data1, contentLength: 3);
      final path2 = await svc.saveUpload(
          rawName: 'file.txt', data: data2, contentLength: 3);

      expect(path1.endsWith('file.txt'), isTrue);
      expect(path2.endsWith('file (1).txt'), isTrue);
      expect(File(path1).existsSync(), isTrue);
      expect(File(path2).existsSync(), isTrue);
    });

    test('يُعيد تسمية متزايدة عند تصادم متعدد', () async {
      for (int i = 0; i < 3; i++) {
        await svc.saveUpload(
          rawName: 'dup.bin',
          data: Stream<List<int>>.value([i]),
          contentLength: 1,
        );
      }
      expect(File('${helper.shareDir.path}/dup.bin').existsSync(), isTrue);
      expect(File('${helper.shareDir.path}/dup (1).bin').existsSync(), isTrue);
      expect(File('${helper.shareDir.path}/dup (2).bin').existsSync(), isTrue);
    });

    test('يُنظّف اسماً يحتوي .. ويحفظه', () async {
      // .. يُنظَّف إلى _ ولا يُرفض في saveUpload (sanitizeName يُعالجه)
      final path = await svc.saveUpload(
        rawName: 'my..file.txt',
        data: Stream<List<int>>.value([65]),
        contentLength: 1,
      );
      expect(File(path).existsSync(), isTrue);
    });

    test('لا يترك ملف temp عند نجاح الحفظ', () async {
      await svc.saveUpload(
        rawName: 'clean.txt',
        data: Stream<List<int>>.value([42]),
        contentLength: 1,
      );
      final temps = Directory(helper.shareDir.path)
          .listSync()
          .where((e) => e.path.endsWith('.apex_tmp'))
          .toList();
      expect(temps, isEmpty);
    });
  });

  // ── deleteFile ─────────────────────────────────────────────────────────────

  group('deleteFile', () {
    test('يحذف ملفاً موجوداً', () async {
      final file = File('${helper.shareDir.path}/del.txt');
      await file.writeAsString('x');

      await svc.deleteFile('del.txt');
      expect(file.existsSync(), isFalse);
    });

    test('يرمي خطأ إذا الملف غير موجود', () async {
      expect(() => svc.deleteFile('ghost.txt'), throwsException);
    });

    test('يرفض حذف اسم غير آمن', () async {
      expect(() => svc.deleteFile('../outside.txt'), throwsException);
    });
  });
}
