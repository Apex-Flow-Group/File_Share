import 'dart:io';

/// A fresh folder under [parent] that only the current user can open.
///
/// Dart creates folders with the umask (usually 0755), so on Linux and macOS
/// a folder in the shared /tmp is readable by every user of the machine until
/// it is closed with chmod 700. On Windows %TEMP% is already per user.
Future<Directory> createPrivateTemp(Directory parent, String prefix) async {
  final dir = await parent.createTemp(prefix);
  if (Platform.isLinux || Platform.isMacOS) {
    final r = await Process.run('chmod', ['700', dir.path]);
    if (r.exitCode != 0) {
      await dir.delete(recursive: true);
      throw FileSystemException('chmod 700 failed: ${r.stderr}', dir.path);
    }
  }
  return dir;
}
