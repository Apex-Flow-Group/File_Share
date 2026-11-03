import 'dart:io';

import '../../../core/apex_core.dart';
import '../../../models/device.dart';
import '../../../services/folder_zip_service.dart';
import '../data/send_http.dart';

/// Zips [folderPath] and sends it as "<folder>.zip", for the phone and the TV
/// alike. The zip is removed whatever the outcome. [label] names it for the
/// notification. [onZipped] runs once the zip is ready, before sending.
Future<({SendOutcome outcome, String label})> sendFolderZipped(
    String folderPath, Device device, {void Function()? onZipped}) async {
  final label = '${folderPath.split(Platform.pathSeparator).last}.zip';
  String? zipPath;
  try {
    zipPath = await FolderZipService.zipFolder(folderPath);
    onZipped?.call();
    final outcome = await ApexCore.instance.sendFileWithName(zipPath, label, device);
    return (outcome: outcome, label: label);
  } finally {
    if (zipPath != null) {
      await FolderZipService.cleanupTemp(zipPath);
    }
  }
}
