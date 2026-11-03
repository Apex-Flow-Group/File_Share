import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:flutter_test/flutter_test.dart';

/// A name already at the 255-byte limit must still fit after "_1" is added,
/// or the second file with that name fails and is lost.
void main() {
  late Directory root;
  late Directory folder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('apex_move_long_');
    folder = Directory('${root.path}/save')..createSync();
  });

  tearDown(() => root.delete(recursive: true));

  var count = 0;
  File temp(String text) => File('${root.path}/${count++}.part')..writeAsStringSync(text);

  String nameOf(File f) => f.path.split(Platform.pathSeparator).last;

  test('a second file with a 255-byte name is saved beside the first', () async {
    final name = '${'a' * 251}.txt';
    expect(utf8.encode(name).length, 255);

    final first = await moveIntoFolder(temp('1'), folder, name);
    final second = await moveIntoFolder(temp('2'), folder, name);

    expect(first.readAsStringSync(), '1');
    expect(second.readAsStringSync(), '2');
    expect(nameOf(second), endsWith('_1.txt'));
    expect(utf8.encode(nameOf(second)).length, lessThanOrEqualTo(255));
  });

  test('an Arabic name is shortened by whole letters, counted in bytes', () async {
    final name = '${'ت' * 125}.txt';
    expect(utf8.encode(name).length, 254);

    await moveIntoFolder(temp('1'), folder, name);
    final second = await moveIntoFolder(temp('2'), folder, name);

    expect(second.readAsStringSync(), '2');
    expect(nameOf(second), endsWith('_1.txt'));
    expect(nameOf(second), startsWith('ت' * 124));
    expect(utf8.encode(nameOf(second)).length, lessThanOrEqualTo(255));
  });

  test('a long name without an extension also fits', () async {
    final name = 'b' * 255;
    await moveIntoFolder(temp('1'), folder, name);
    final second = await moveIntoFolder(temp('2'), folder, name);

    expect(second.readAsStringSync(), '2');
    expect(nameOf(second), endsWith('_1'));
    expect(utf8.encode(nameOf(second)).length, lessThanOrEqualTo(255));
  });
}
