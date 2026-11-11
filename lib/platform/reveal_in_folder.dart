import 'dart:io';

/// Opens the folder that holds [filePath] on Windows and Linux: true when it
/// opened, false when it failed, null on other systems, which open folders
/// their own way. The caller checks that the folder exists first: explorer.exe
/// opens another place for a missing one and its exit code is always 1.
Future<bool?> revealOnDesktop(String filePath) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', windowsRevealArgs(filePath));
    return true;
  }
  if (Platform.isLinux) {
    return (await Process.run('xdg-open', [File(filePath).parent.path])).exitCode == 0;
  }
  return null;
}

/// Opens [dirPath] itself on Windows and Linux, as [revealOnDesktop] answers.
/// "/select," on a file that is not there opens the Desktop, so a folder is
/// never reached through a file.
Future<bool?> openFolderOnDesktop(String dirPath) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', [windowsPath(dirPath)]);
    return true;
  }
  if (Platform.isLinux) {
    return (await Process.run('xdg-open', [dirPath])).exitCode == 0;
  }
  return null;
}

/// Saved paths are built with "/" after the Windows root ("<Documents>/ApexShare/Apps").
/// explorer.exe does not read "/" and opens Documents instead of the folder.
String windowsPath(String path) => path.replaceAll('/', r'\');

/// explorer.exe arguments that open the file's folder with the file selected.
List<String> windowsRevealArgs(String filePath) => ['/select,', windowsPath(filePath)];
