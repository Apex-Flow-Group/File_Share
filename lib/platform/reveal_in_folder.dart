import 'dart:io';

/// Opens the folder that holds [filePath] on Windows and Linux. False on other
/// systems, which open folders their own way.
Future<bool> revealOnDesktop(String filePath) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', windowsRevealArgs(filePath));
    return true;
  }
  if (Platform.isLinux) {
    await Process.run('xdg-open', [File(filePath).parent.path]);
    return true;
  }
  return false;
}

/// Saved paths are built with "/" after the Windows root ("<Documents>/ApexShare/Apps").
/// explorer.exe does not read "/" and opens Documents instead of the folder.
String windowsPath(String path) => path.replaceAll('/', r'\');

/// explorer.exe arguments that open the file's folder with the file selected.
List<String> windowsRevealArgs(String filePath) => ['/select,', windowsPath(filePath)];
