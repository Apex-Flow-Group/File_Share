import '../models/device.dart';

class FileReceivedEvent {
  final String fileName;
  final int fileSize;
  final String fromDevice;
  final String filePath;
  final bool isLastInBatch;
  final int batchTotal;
  final int batchIndex;
  FileReceivedEvent({
    required this.fileName,
    required this.fileSize,
    required this.fromDevice,
    required this.filePath,
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
}

class ConnectionRequest {
  final Device device;
  final String fileName;
  final int fileSize;
  final int fileCount;
  final List<String> fileNames;
  final RequestKind kind;
  final Function(bool) onResponse;
  ConnectionRequest({
    required this.device,
    required this.fileName,
    required this.onResponse,
    this.fileSize = 0,
    this.fileCount = 1,
    this.fileNames = const [],
    this.kind = RequestKind.files,
  });

  bool get asksToConnect => kind == RequestKind.connect;
}
