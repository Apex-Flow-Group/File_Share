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

  void updateProgress(TransferProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
  }

  void clearProgress() {
    _currentProgress = null;
    _isCancelled = false;
    _progressController.add(null);
  }

  void cancelTransfer() {
    _isCancelled = true;
  }

  bool get isCancelled => _isCancelled;

  void dispose() {
    _progressController.close();
  }
}
