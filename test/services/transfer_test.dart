// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/models/device.dart';
import 'package:apex_file_share/models/transfer_progress.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fake Receiver ────────────────────────────────────────────────────────────

/// يحاكي جهاز المستقبل بالبروتوكول الكامل:
/// POST /request  → قبول/رفض
/// POST /upload   → استقبال الملف
/// GET  /ping     → pong
class FakeReceiver {
  HttpServer? _server;

  /// الملفات التي وصلت: name → bytes
  final Map<String, List<int>> receivedFiles = {};

  /// عدد طلبات الإذن الواردة
  int requestCount = 0;

  /// بيانات آخر batch request
  Map<String, String>? lastBatchParams;

  /// إذا true، يرفض الطلب القادم
  bool rejectNext = false;

  Future<int> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
    return _server!.port;
  }

  Future<void> stop() => _server?.close(force: true) ?? Future.value();

  Future<void> _handle(HttpRequest req) async {
    try {
      if (req.method == 'GET' && req.uri.path == '/ping') {
        req.response
          ..statusCode = 200
          ..write('pong');
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && req.uri.path == '/request') {
        requestCount++;
        lastBatchParams = Map.from(req.uri.queryParameters);
        final accepted = !rejectNext;
        rejectNext = false;
        req.response
          ..statusCode = 200
          ..write(jsonEncode({'accepted': accepted}));
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && req.uri.path == '/upload') {
        final name = req.uri.queryParameters['name'] ?? 'unknown';
        final bytes = <int>[];
        await for (final chunk in req) {
          bytes.addAll(chunk);
        }
        receivedFiles[name] = bytes;
        req.response
          ..statusCode = 200
          ..write(jsonEncode({'success': true}));
        await req.response.close();
        return;
      }

      req.response.statusCode = 404;
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }
}

// ─── HTTP Send Helpers ────────────────────────────────────────────────────────

/// يرسل ملفاً واحداً — يحاكي ApexCore._sendViaHttp الجديد (بدون batch)
Future<bool> _sendSingle(File file, String fileName, Device target,
    {String sender = 'TestDevice'}) async {
  if (!await file.exists()) {
    return false;
  }
  final size = await file.length();
  return _batchSend([(file: file, name: fileName, size: size)], target,
      sender: sender);
}

/// يرسل مجموعة ملفات — يحاكي ApexCore._sendFilesViaHttp
/// طلب إذن واحد يحتوي كل المعلومات، ثم رفع كل ملف
Future<bool> _batchSend(
  List<({File file, String name, int size})> files,
  Device target, {
  String sender = 'TestDevice',
}) async {
  // 1. ping
  if (!await _ping(target)) {
    return false;
  }

  // 2. طلب إذن واحد بكل المعلومات
  if (!await _requestBatch(files, target, sender)) {
    return false;
  }

  // 3. رفع كل ملف
  final progress = TransferProgressService();
  progress.startBatch(files.length);
  int success = 0;
  for (final f in files) {
    if (progress.isCancelled) {
      break;
    }
    if (await _upload(f.file, f.name, f.size, target, sender)) {
      success++;
    }
    progress.nextFile();
  }
  progress.clearProgress();
  return success == files.length;
}

Future<bool> _ping(Device target) async {
  HttpClient? c;
  try {
    c = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    final req = await c.get(target.ip, target.port, '/ping');
    final res = await req.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    c?.close(force: true);
  }
}

Future<bool> _requestBatch(
  List<({File file, String name, int size})> files,
  Device target,
  String sender,
) async {
  HttpClient? c;
  try {
    c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final uri = Uri.http('${target.ip}:${target.port}', '/request', {
      'from': sender,
      'ip': '127.0.0.1',
      'name': files.length == 1 ? files.first.name : '${files.length} ملفات',
      'size': files.fold<int>(0, (s, f) => s + f.size).toString(),
      'total': files.length.toString(),
      'names': files.map((f) => f.name).join(','),
      'sizes': files.map((f) => f.size.toString()).join(','),
    });
    final req = await c.postUrl(uri);
    final res = await req.close();
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    return body['accepted'] == true;
  } catch (_) {
    return false;
  } finally {
    c?.close(force: true);
  }
}

Future<bool> _upload(
    File file, String name, int size, Device target, String sender) async {
  HttpClient? c;
  try {
    final progress = TransferProgressService();
    final start = DateTime.now();
    c = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    final uri = Uri.http('${target.ip}:${target.port}', '/upload',
        {'name': name, 'from': sender});
    final req = await c.postUrl(uri);
    req.headers.set('Content-Length', size.toString());
    int transferred = 0;
    await for (final chunk in file.openRead()) {
      if (progress.isCancelled) {
        req.abort();
        return false;
      }
      req.add(chunk);
      transferred += chunk.length;
      progress.updateProgress(TransferProgress(
        fileName: name,
        totalBytes: size,
        transferredBytes: transferred,
        status: TransferStatus.transferring,
        startTime: start,
      ));
    }
    final res = await req.close();
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    return body['success'] == true;
  } catch (_) {
    return false;
  } finally {
    c?.close(force: true);
  }
}

// ─── Test Setup ───────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;
  late FakeReceiver receiver;
  late Device target;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('apex_test_');
    receiver = FakeReceiver();
    final port = await receiver.start();
    target = Device(
      id: 'test-device',
      name: 'TestReceiver',
      type: 'desktop',
      ip: '127.0.0.1',
      port: port,
    );
    TransferProgressService().clearProgress();
  });

  tearDown(() async {
    await receiver.stop();
    await tempDir.delete(recursive: true);
    TransferProgressService().clearProgress();
  });

  // ── إرسال ملف واحد ──────────────────────────────────────────────────────────

  group('إرسال ملف واحد', () {
    test('يصل الملف بالمحتوى الصحيح', () async {
      final file = File('${tempDir.path}/hello.txt');
      await file.writeAsString('مرحباً من Apex');

      final ok = await _sendSingle(file, 'hello.txt', target);

      expect(ok, isTrue);
      expect(receiver.receivedFiles.keys, contains('hello.txt'));
      expect(utf8.decode(receiver.receivedFiles['hello.txt']!),
          equals('مرحباً من Apex'));
    });

    test('طلب إذن واحد فقط يُرسَل للملف الواحد', () async {
      final file = File('${tempDir.path}/one.txt')..writeAsStringSync('test');

      await _sendSingle(file, 'one.txt', target);

      expect(receiver.requestCount, equals(1));
    });

    test('يفشل إذا الملف غير موجود — لا يصل شيء', () async {
      final ok = await _sendSingle(
          File('${tempDir.path}/ghost.txt'), 'ghost.txt', target);

      expect(ok, isFalse);
      expect(receiver.receivedFiles, isEmpty);
      expect(receiver.requestCount, equals(0));
    });

    test('يفشل إذا رفض المستقبل الطلب', () async {
      receiver.rejectNext = true;
      final file = File('${tempDir.path}/secret.txt')..writeAsStringSync('سري');

      final ok = await _sendSingle(file, 'secret.txt', target);

      expect(ok, isFalse);
      expect(receiver.receivedFiles, isEmpty);
    });

    test('يرسل ملفاً فارغاً بنجاح', () async {
      final file = File('${tempDir.path}/empty.txt')..writeAsBytesSync([]);

      final ok = await _sendSingle(file, 'empty.txt', target);

      expect(ok, isTrue);
      expect(receiver.receivedFiles['empty.txt'], isEmpty);
    });

    test('يرسل ملفاً كبيراً (2 MB) والمحتوى يصل كاملاً', () async {
      final data = List.filled(2 * 1024 * 1024, 0xAB);
      final file = File('${tempDir.path}/big.bin')..writeAsBytesSync(data);

      final ok = await _sendSingle(file, 'big.bin', target);

      expect(ok, isTrue);
      expect(
          receiver.receivedFiles['big.bin']?.length, equals(2 * 1024 * 1024));
    });

    test('يُحدَّث progress أثناء الإرسال', () async {
      final data = List.filled(512 * 1024, 0x01);
      final file = File('${tempDir.path}/progress.bin')..writeAsBytesSync(data);

      final events = <TransferProgress>[];
      final sub = TransferProgressService()
          .progressStream
          .where((p) => p != null)
          .cast<TransferProgress>()
          .listen(events.add);

      await _sendSingle(file, 'progress.bin', target);
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.last.transferredBytes, equals(data.length));
    });

    test('يُلغى الإرسال عند cancelTransfer — التوقف قبل اكتمال الدفعة',
        () async {
      // ملف صغير جداً لا يمكن إلغاؤه أثناء الرفع، لكن يمكن إلغاء الدفعة قبل الملف التالي
      final entries = await _makeFiles(tempDir, {
        'c1.txt': 'first',
        'c2.txt': 'second',
        'c3.txt': 'third',
      });

      final progress = TransferProgressService();
      if (!await _ping(target)) {
        fail('ping failed');
      }
      if (!await _requestBatch(entries, target, 'TestDevice')) {
        fail('rejected');
      }

      progress.startBatch(entries.length);
      int sent = 0;
      for (final f in entries) {
        if (progress.isCancelled) {
          break;
        }
        await _upload(f.file, f.name, f.size, target, 'TestDevice');
        sent++;
        progress.nextFile();
        if (sent == 1) {
          progress.cancelTransfer(); // ألغِ بعد الملف الأول
        }
      }
      progress.clearProgress();

      expect(sent, equals(1), reason: 'يجب أن يتوقف بعد الملف الأول');
      expect(receiver.receivedFiles.length, equals(1));
    });
  });

  // ── إرسال متعدد: طلب إذن واحد ───────────────────────────────────────────────

  group('إرسال ملفات متعددة — طلب إذن واحد', () {
    test('3 ملفات → طلب إذن واحد فقط يحتوي كل المعلومات', () async {
      final entries = await _makeFiles(tempDir, {
        'a.txt': 'محتوى أ',
        'b.txt': 'محتوى ب',
        'c.txt': 'محتوى ج',
      });

      await _batchSend(entries, target);

      expect(receiver.requestCount, equals(1), reason: 'يجب طلب إذن واحد فقط');
      expect(receiver.lastBatchParams?['total'], equals('3'));
      expect(receiver.lastBatchParams?['names'], contains('a.txt'));
    });

    test('3 ملفات تصل جميعها بالمحتوى الصحيح', () async {
      final entries = await _makeFiles(tempDir, {
        'x.txt': 'X content',
        'y.txt': 'Y content',
        'z.txt': 'Z content',
      });

      final ok = await _batchSend(entries, target);

      expect(ok, isTrue);
      expect(receiver.receivedFiles.keys,
          containsAll(['x.txt', 'y.txt', 'z.txt']));
      expect(utf8.decode(receiver.receivedFiles['x.txt']!), 'X content');
      expect(utf8.decode(receiver.receivedFiles['y.txt']!), 'Y content');
      expect(utf8.decode(receiver.receivedFiles['z.txt']!), 'Z content');
    });

    test('إذا رُفض الطلب — لا يُرسَل أي ملف', () async {
      receiver.rejectNext = true;
      final entries = await _makeFiles(tempDir, {
        'f1.txt': 'data1',
        'f2.txt': 'data2',
      });

      final ok = await _batchSend(entries, target);

      expect(ok, isFalse);
      expect(receiver.receivedFiles, isEmpty);
      expect(receiver.requestCount, equals(1));
    });

    test('حجم batch في الطلب يساوي مجموع أحجام الملفات', () async {
      final entries = await _makeFiles(tempDir, {
        'p1.txt': '12345', // 5 bytes
        'p2.txt': '1234567890', // 10 bytes
      });

      await _batchSend(entries, target);

      final totalSize = int.parse(receiver.lastBatchParams?['size'] ?? '0');
      expect(totalSize, equals(15));
    });

    test('TransferProgressService يتتبع كل ملف على حدة', () async {
      final entries = await _makeFiles(tempDir, {
        'seq1.txt': 'data',
        'seq2.txt': 'more data',
        'seq3.txt': 'even more',
      });

      final progress = TransferProgressService();
      progress.startBatch(entries.length);

      final fileNames = <String>[];
      final sub = progress.progressStream
          .where((p) => p != null)
          .cast<TransferProgress>()
          .listen((p) {
        if (fileNames.isEmpty || fileNames.last != p.fileName) {
          fileNames.add(p.fileName);
        }
      });

      for (final f in entries) {
        if (progress.isCancelled) {
          break;
        }
        await _upload(f.file, f.name, f.size, target, 'TestDevice');
        progress.nextFile();
      }
      progress.clearProgress();
      await sub.cancel();

      expect(fileNames, containsAll(['seq1.txt', 'seq2.txt', 'seq3.txt']));
    });

    test('يُلغى الدفعة بعد أول ملف', () async {
      final entries = await _makeFiles(tempDir, {
        'b1.txt': 'first',
        'b2.txt': 'second',
        'b3.txt': 'third',
      });

      final progress = TransferProgressService();
      progress.startBatch(entries.length);

      int sent = 0;
      for (final f in entries) {
        if (progress.isCancelled) {
          break;
        }
        await _upload(f.file, f.name, f.size, target, 'TestDevice');
        sent++;
        progress.nextFile();
        if (sent == 1) {
          progress.cancelTransfer();
        }
      }
      progress.clearProgress();

      expect(sent, equals(1));
      expect(receiver.receivedFiles.length, equals(1));
    });

    test('10 ملفات صغيرة تصل جميعها', () async {
      final map = <String, String>{};
      for (var i = 0; i < 10; i++) {
        map['file_$i.dat'] = 'content $i';
      }
      final entries = await _makeFiles(tempDir, map);

      final ok = await _batchSend(entries, target);

      expect(ok, isTrue);
      expect(receiver.receivedFiles.length, equals(10));
    });
  });

  // ── TransferProgressService ──────────────────────────────────────────────────

  group('TransferProgressService', () {
    test('clearProgress يعيد الحالة الأولية', () {
      final svc = TransferProgressService();
      svc.startBatch(5);
      svc.nextFile();
      svc.updateProgress(TransferProgress(
        fileName: 'x.txt',
        totalBytes: 100,
        transferredBytes: 50,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      ));

      svc.clearProgress();

      expect(svc.currentProgress, isNull);
      expect(svc.totalFiles, equals(1));
      expect(svc.currentFileIndex, equals(0));
      expect(svc.isCancelled, isFalse);
      expect(svc.isTransferring, isFalse);
    });

    test('cancelTransfer يُوقف الإرسال', () {
      final svc = TransferProgressService();
      expect(svc.isCancelled, isFalse);
      svc.cancelTransfer();
      expect(svc.isCancelled, isTrue);
    });

    test('isTransferring يعكس وجود progress نشط', () {
      final svc = TransferProgressService();
      expect(svc.isTransferring, isFalse);
      svc.updateProgress(TransferProgress(
        fileName: 'f.txt',
        totalBytes: 100,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      ));
      expect(svc.isTransferring, isTrue);
      svc.clearProgress();
      expect(svc.isTransferring, isFalse);
    });

    test('startBatch يضبط العداد', () {
      final svc = TransferProgressService();
      svc.startBatch(7);
      expect(svc.totalFiles, equals(7));
      expect(svc.currentFileIndex, equals(0));
    });

    test('nextFile يزيد المؤشر', () {
      final svc = TransferProgressService();
      svc.startBatch(3);
      svc.nextFile();
      expect(svc.currentFileIndex, equals(1));
      svc.nextFile();
      expect(svc.currentFileIndex, equals(2));
    });
  });

  // ── TransferProgress حسابات ──────────────────────────────────────────────────

  group('TransferProgress حسابات', () {
    test('percentage تحسب بشكل صحيح', () {
      final p = TransferProgress(
        fileName: 'f.txt',
        totalBytes: 200,
        transferredBytes: 50,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      );
      expect(p.percentage, equals(25.0));
    });

    test('percentage = 0 عند totalBytes = 0', () {
      final p = TransferProgress(
        fileName: 'f.txt',
        totalBytes: 0,
        transferredBytes: 0,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      );
      expect(p.percentage, equals(0.0));
    });

    test('percentage لا تتجاوز 100', () {
      final p = TransferProgress(
        fileName: 'f.txt',
        totalBytes: 100,
        transferredBytes: 150,
        status: TransferStatus.transferring,
        startTime: DateTime.now(),
      );
      expect(p.percentage, equals(100.0));
    });

    test('copyWith يغيّر الحقول المحددة فقط', () {
      final p = TransferProgress(
        fileName: 'original.txt',
        totalBytes: 1000,
        transferredBytes: 0,
        status: TransferStatus.idle,
        startTime: DateTime.now(),
      );
      final p2 = p.copyWith(
        transferredBytes: 500,
        status: TransferStatus.transferring,
      );
      expect(p2.fileName, equals('original.txt'));
      expect(p2.totalBytes, equals(1000));
      expect(p2.transferredBytes, equals(500));
      expect(p2.status, equals(TransferStatus.transferring));
    });
  });
}

// ─── Helper ───────────────────────────────────────────────────────────────────

Future<List<({File file, String name, int size})>> _makeFiles(
  Directory dir,
  Map<String, String> nameToContent,
) async {
  final result = <({File file, String name, int size})>[];
  for (final entry in nameToContent.entries) {
    final f = File('${dir.path}/${entry.key}');
    await f.writeAsString(entry.value);
    result.add((file: f, name: entry.key, size: await f.length()));
  }
  return result;
}
