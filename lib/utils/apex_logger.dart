import 'dart:async';
import 'package:flutter/foundation.dart';

enum LogLevel { info, success, warning, error, debug }

class LogEntry {
  final String tag;
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry(this.tag, this.message, this.level) : timestamp = DateTime.now();
}

class ApexLogger {
  static final ApexLogger instance = ApexLogger._();
  ApexLogger._();

  final _controller = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get stream => _controller.stream;

  void log(String tag, String message, [LogLevel level = LogLevel.info]) {
    final entry = LogEntry(tag, message, level);
    _controller.add(entry);
    
    if (kDebugMode) {
      final emoji = _getEmoji(level);
      debugPrint('$emoji [$tag] $message');
    }
  }

  String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.success: return '✅';
      case LogLevel.error: return '❌';
      case LogLevel.warning: return '⚠️';
      case LogLevel.debug: return '🔍';
      default: return 'ℹ️';
    }
  }

  void dispose() => _controller.close();
}
