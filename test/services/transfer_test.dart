import 'package:apex_file_share/models/transfer_progress.dart';
import 'package:apex_file_share/services/transfer_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Sending and receiving are tested with the real code in
// test/features/send/data/send_http_test.dart and
// test/features/receive/data/receive_http_test.dart.

void main() {
  setUp(() => TransferProgressService().clearProgress());
  tearDown(() => TransferProgressService().clearProgress());

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
