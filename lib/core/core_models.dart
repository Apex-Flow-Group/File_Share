import 'dart:async';

import '../models/device.dart';

class FileReceivedEvent {
  final String fileName;
  final int fileSize;
  final String fromDevice;

  /// The sender's real address, from the connection; null over Nearby.
  /// The file's line goes to this address's chat, not to the name it gave.
  final String? fromAddress;
  final String filePath;
  final bool isLastInBatch;
  final int batchTotal;
  final int batchIndex;
  FileReceivedEvent({
    required this.fileName,
    required this.fileSize,
    required this.fromDevice,
    required this.filePath,
    this.fromAddress,
    this.isLastInBatch = true,
    this.batchTotal = 1,
    this.batchIndex = 1,
  });
}

/// What the user is asked to allow.
enum RequestKind {
  /// Receive the listed files.
  files,

  /// Let a nearby phone connect, before it can offer any file.
  connect,

  /// Let a device open the shared folder.
  shareFolder,

  /// Let a device send chat messages until the app closes.
  chat,
}

class ConnectionRequest {
  final Device device;
  final String fileName;
  final int fileSize;
  final int fileCount;
  final List<String> fileNames;
  final RequestKind kind;

  /// For [RequestKind.shareFolder]: the device could also upload.
  final bool allowsUploads;
  final Function(bool) onResponse;
  ConnectionRequest({
    required this.device,
    required this.fileName,
    required this.onResponse,
    this.fileSize = 0,
    this.fileCount = 1,
    this.fileNames = const [],
    this.kind = RequestKind.files,
    this.allowsUploads = false,
  });

  bool get asksToConnect => kind == RequestKind.connect;

  final _closed = Completer<void>();

  /// Completes when the asker stops waiting, answered or not, so a dialog
  /// still showing this request closes instead of taking a late answer.
  Future<void> get closed => _closed.future;
  bool get isClosed => _closed.isCompleted;

  void close() {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}
