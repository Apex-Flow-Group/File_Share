import 'dart:io';

import '../features/receive/data/sender_log.dart';
import '../utils/apex_logger.dart';
import '../utils/file_utils.dart';

class FileOperationsService {
  FileOperationsService({this.senders});

  /// A deleted file's sender line goes with it.
  final SenderLog? senders;

  Future<int> deleteFiles(Set<String> filePaths) async {
    int deletedCount = 0;

    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          senders?.forget(filePath);
          deletedCount++;
        }
      } catch (e) {
        ApexLogger.instance.log('FILE', '❌ Failed to delete file: $e', LogLevel.error);
      }
    }

    return deletedCount;
  }

  Future<void> openFile(String path) async {
    try {
      await FileUtils.openFile(path);
    } catch (e) {
      ApexLogger.instance.log('FILE', '❌ Failed to open file: $e', LogLevel.error);
      rethrow;
    }
  }

  Future<void> openFileLocation(String path) async {
    try {
      await FileUtils.openFileLocation(path);
    } catch (e) {
      ApexLogger.instance.log('FILE', '❌ Failed to open folder: $e', LogLevel.error);
      rethrow;
    }
  }
}
