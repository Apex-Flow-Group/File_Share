import 'dart:io';

import '../utils/path_utils.dart';

/// Saves [temp] as [name] in the user's Downloads through MediaStore on
/// Android, and returns where it went; null on other systems, which move it
/// into a folder of their own. Throws when Android could not save it.
Future<String?> saveThroughMediaStore(File temp, String name) async {
  if (!Platform.isAndroid) {
    return null;
  }
  final saved = await PathUtils.saveToPublicDownloads(name, temp.path);
  if (saved == null) {
    throw FileSystemException('Could not save to Downloads', name);
  }
  return saved;
}
