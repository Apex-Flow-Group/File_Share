import 'dart:async';
import '../models/transfer_progress.dart';

class TransferProgressService {
  static final TransferProgressService _instance =
      TransferProgressService._internal();
  factory TransferProgressService() => _instance;
  TransferProgressService._internal();

  final _progressController = StreamController<TransferProgress?>.broadcast();
  Stream<TransferProgress?> get progressStream => _progressController.stream;

  TransferProgress? _currentProgress;
  TransferProgress? get currentProgress => _currentProgress;
  bool _isCancelled = false;

  // Multi-file tracking
  int _totalFiles = 1;
  int _currentFileIndex = 0;
  int get totalFiles => _totalFiles;
  int get currentFileIndex => _currentFileIndex;

  // حماية أقوى: flag يبقى true طوال فترة الدفعة بما في ذلك الفراغات بين الملفات
  bool _isBatchActive = false;
  bool get isBatchActive => _isBatchActive;

  // تحديد اتجاه النقل: إرسال أم استقبال
  bool _isSending = false;
  bool get isSending => _isSending;

  void startBatch(int total) {
    _totalFiles = total;
    _currentFileIndex = 0;
    _isCancelled = false;
    _isBatchActive = true;
    _isSending = true;
  }

  void nextFile() {
    _currentFileIndex++;
  }

  void updateProgress(TransferProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
  }

  void clearProgress() {
    _currentProgress = null;
    _isCancelled = false;
    _isCancelledReceive = false;
    _isBatchActive = false;
    _isSending = false;
    _totalFiles = 1;
    _currentFileIndex = 0;
    _progressController.add(null);
  }

  /// يعيد true إذا كان هناك نقل جارٍ أو دفعة نشطة
  bool get isTransferring => _currentProgress != null || _isBatchActive;

  void cancelTransfer() {
    _isCancelled = true;
  }

  bool get isCancelled => _isCancelled;

  // إلغاء الاستقبال
  bool _isCancelledReceive = false;
  bool get isCancelledReceive => _isCancelledReceive;

  void cancelReceive() {
    _isCancelledReceive = true;
  }

  void dispose() {
    _progressController.close();
  }
}
