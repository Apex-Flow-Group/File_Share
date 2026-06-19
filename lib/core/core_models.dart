import '../models/device.dart';

class FileReceivedEvent {
  final String fileName;
  final int fileSize;
  final String fromDevice;
  final String filePath;
  FileReceivedEvent({
    required this.fileName,
    required this.fileSize,
    required this.fromDevice,
    required this.filePath,
  });
}

class ConnectionRequest {
  final Device device;
  final String fileName;
  final int fileSize;
  final int fileCount;
  final List<String> fileNames;
  final Function(bool) onResponse;
  ConnectionRequest({
    required this.device,
    required this.fileName,
    required this.onResponse,
    this.fileSize = 0,
    this.fileCount = 1,
    this.fileNames = const [],
  });
}
