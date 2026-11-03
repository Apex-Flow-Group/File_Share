@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:apex_file_share/core/files/save_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the download is written where other users cannot read it', () async {
    final root = await Directory.systemTemp.createTemp('apex_download_private_');
    addTearDown(() => root.delete(recursive: true));
    late int folderMode;
    await saveDownload(Stream.value([1, 2, 3]), 'a.bin', tempRoot: root,
        place: (temp, name) async {
      folderMode = temp.parent.statSync().mode;
      return temp.path;
    });
    expect(folderMode & 0x3F, 0);
  });
}
