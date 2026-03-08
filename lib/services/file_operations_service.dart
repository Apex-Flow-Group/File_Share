import 'dart:io';
import '../utils/apex_logger.dart';
import '../utils/file_utils.dart';

class FileOperationsService {
  Future<int> deleteFiles(
    Set<String> filePaths, {
    required bool deleteFromFolder,
  }) async {
    int deletedCount = 0;

    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (deleteFromFolder && await file.exists()) {
          await file.delete();
          deletedCount++;
        } else if (!deleteFromFolder) {
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
