import '../l10n/generated/app_localizations.dart';
enum TransferStatus {
  idle,
  connecting,
  transferring,
  completed,
  failed,
  cancelled,
}

class TransferProgress {
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final DateTime startTime;
  final String? error;
  
  TransferProgress({
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    required this.startTime,
    this.error,
  });
  
  double get percentage {
    if (totalBytes == 0) {
      return 0;
    }
    return (transferredBytes / totalBytes * 100).clamp(0, 100);
  }
  
  double get speed {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed == 0) {
      return 0;
    }
    return transferredBytes / elapsed; // bytes per second
  }
  
  Duration get remainingTime {
    if (speed == 0) {
      return Duration.zero;
    }
    final remaining = totalBytes - transferredBytes;
    return Duration(seconds: (remaining / speed).round());
  }
  
  String get speedFormatted {
    if (speed < 1024) {
      return '${speed.toStringAsFixed(0)} B/s';
    }
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
  
  String remainingTimeFormatted(AppLocalizations l10n) {
    final seconds = remainingTime.inSeconds;
    if (seconds < 60) {
      return l10n.timeSecondsShort(seconds);
    }
    if (seconds < 3600) {
      return l10n.timeMinutesShort((seconds / 60).round());
    }
    return l10n.timeHoursShort((seconds / 3600).round());
  }
  
  TransferProgress copyWith({
    String? fileName,
    int? totalBytes,
    int? transferredBytes,
    TransferStatus? status,
    DateTime? startTime,
    String? error,
  }) {
    return TransferProgress(
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      error: error ?? this.error,
    );
  }
}
