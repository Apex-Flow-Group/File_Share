import 'dart:io';

/// Closes [entity] to every other user of the machine: chmod 700 for a
/// folder, 600 for a file. Dart creates both with the umask (usually 0755
/// and 0644), so on Linux and macOS a private key would be readable by all.
/// On Windows and Android the app's own folders are already per user.
Future<void> keepOwnerOnly(FileSystemEntity entity) async {
  if (!Platform.isLinux && !Platform.isMacOS) {
    return;
  }
  final mode = entity is Directory ? '700' : '600';
  final r = await Process.run('chmod', [mode, entity.path]);
  if (r.exitCode != 0) {
    throw FileSystemException('chmod $mode failed: ${r.stderr}', entity.path);
  }
}

/// Where this install keeps its identity key. On Windows it is the local
/// AppData, not the roaming one the support folder is in: a roaming profile
/// would copy the key to every machine the user signs in to, and they would
/// all be one device.
Directory identityFolder(Directory supportFolder) {
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) {
      return Directory('$local\\ApexFileShare\\identity');
    }
  }
  return Directory('${supportFolder.path}/identity');
}
