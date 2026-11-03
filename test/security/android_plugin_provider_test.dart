@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the open_filex FileProvider paths are narrowed by the app', () {
    // open_filex merges its own FileProvider with @xml/filepaths, which lists
    // root-path "." (the whole file system). A resource of the same name in
    // the app replaces the library's at build time.
    final f = File('android/app/src/main/res/xml/filepaths.xml');
    expect(f.existsSync(), isTrue, reason: 'Nothing overrides open_filex filepaths.xml');
    final open = RegExp(r'<[a-z-]+-path[^>]*path="(\.?/?)"').allMatches(f.readAsStringSync());
    expect(open, isEmpty);
    expect(f.readAsStringSync().contains('<root-path'), isFalse);
  });
}
