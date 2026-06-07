import 'dart:async';
import '../models/transfer_progress.dart';

class TransferProgressService {
  static final TransferProgressService _instance = TransferProgressService._internal();
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

  void startBatch(int total) {
    _totalFiles = total;
    _currentFileIndex = 0;
    _isCancelled = false;
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
    _totalFiles = 1;
    _currentFileIndex = 0;
    _progressController.add(null);
  }

  bool get isTransferring => _currentProgress != null;

  void cancelTransfer() {
    _isCancelled = true;
  }

  bool get isCancelled => _isCancelled;

  void dispose() {
    _progressController.close();
  }
}
