import 'dart:io';

import 'safe_file_name.dart';

/// Saves a file downloaded from another device. [place] moves the finished
/// temp file to where it belongs under the cleaned name and returns its path.
///
/// The bytes go to a fresh folder of our own (mkdtemp, owner-only on Linux and
/// macOS), never to a path built from the remote name, and that folder is
/// removed whatever happens, so a cut connection leaves no half file.
Future<String> saveDownload(
  Stream<List<int>> body,
  String? remoteName, {
  required Directory tempRoot,
  required Future<String> Function(File temp, String name) place,
}) async {
  final name = safeFileName(remoteName);
  final work = await tempRoot.createTemp('apex_dl_');
  try {
    final temp = File('${work.path}${Platform.pathSeparator}download.part');
    final sink = temp.openWrite();
    try {
      await sink.addStream(body);
    } catch (_) {
      // close() fails too after a stream error; keep the first error.
      await sink.close().catchError((_) {});
      rethrow;
    }
    await sink.close();
    return await place(temp, name);
  } finally {
    if (await work.exists()) {
      await work.delete(recursive: true);
    }
  }
}
