import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// On Linux the system temp folder is /tmp: tmpfs on Fedora, so the final
/// move to ~/Downloads is a copy (rename fails across disks), and a crash
/// mid-copy leaves a cut file under its real name. /tmp is also shared by
/// every user of the machine, who can create /tmp/apex_receive first.
/// Files still arriving must wait beside the save folder, in the user's own
/// folder. A real run cannot be pointed away from ~/Downloads, so this reads
/// the code.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('desktop receive keeps arriving files beside the save folder, not in the system temp', () {
    final core = read('lib/core/apex_core.dart');
    final store = RegExp(r'ReceiveStore\(([\s\S]*?)place:').firstMatch(core);
    expect(store, isNotNull, reason: 'ReceiveStore is no longer built in apex_core.dart; update this guard.');
    final tempFolder = store!.group(1)!;
    expect(tempFolder, contains('PathUtils.getReceivingPath()'),
        reason: 'The receive temp folder is not the one beside the save folder:\n$tempFolder');
  });

  test('the receiving folder is inside the save folder', () {
    final paths = read('lib/utils/path_utils.dart');
    final body = RegExp(r'getReceivingPath\(\)[^{]*\{([\s\S]*?)\n  \}').firstMatch(paths)?.group(1);
    expect(body, isNotNull, reason: 'PathUtils.getReceivingPath() is missing.');
    expect(body, contains('getDownloadPath()'));
    expect(body, isNot(contains('getTemporaryDirectory')));
  });
}
