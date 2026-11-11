import 'package:apex_file_share/platform/reveal_in_folder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a saved Windows path reaches explorer with backslashes only', () {
    expect(windowsPath(r'D:\Docs/ApexShare/Apps/x.apk'), r'D:\Docs\ApexShare\Apps\x.apk',
        reason: 'explorer.exe opens Documents, not the folder, when the path has "/".');
  });

  test('open folder selects the received file in its own folder', () {
    expect(windowsRevealArgs(r'D:\Docs/ApexShare/Apps/my app.apk'),
        ['/select,', r'D:\Docs\ApexShare\Apps\my app.apk']);
  });
}
