import 'dart:io';

import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory folder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('apex_move_test_');
    folder = Directory('${root.path}/save')..createSync();
  });

  tearDown(() => root.delete(recursive: true));

  var count = 0;
  File temp(String text) {
    final f = File('${root.path}/${count++}.part');
    f.writeAsStringSync(text);
    return f;
  }

  test('a file is moved under its name', () async {
    final moved = await moveIntoFolder(temp('a'), folder, 'report.txt');
    expect(moved.path, '${folder.path}${Platform.pathSeparator}report.txt');
    expect(moved.readAsStringSync(), 'a');
  });

  test('an existing file is never replaced: the new one gets _1, then _2', () async {
    File('${folder.path}/report.txt').writeAsStringSync('mine');
    final first = await moveIntoFolder(temp('new 1'), folder, 'report.txt');
    final second = await moveIntoFolder(temp('new 2'), folder, 'report.txt');

    expect(File('${folder.path}/report.txt').readAsStringSync(), 'mine');
    expect(first.uri.pathSegments.last, 'report_1.txt');
    expect(second.uri.pathSegments.last, 'report_2.txt');
  });

  test('a folder with the same name is not touched', () async {
    Directory('${folder.path}/photos').createSync();
    final moved = await moveIntoFolder(temp('x'), folder, 'photos');
    expect(moved.uri.pathSegments.last, 'photos_1');
    expect(Directory('${folder.path}/photos').existsSync(), isTrue);
  });

  test('two files moved at the same time with the same name both survive', () async {
    final results = await Future.wait([
      moveIntoFolder(temp('one'), folder, 'same.txt'),
      moveIntoFolder(temp('two'), folder, 'same.txt'),
    ]);
    expect(results.map((f) => f.readAsStringSync()).toSet(), {'one', 'two'});
  });

  test('the source file is gone after the move', () async {
    final src = temp('x');
    await moveIntoFolder(src, folder, 'x.txt');
    expect(src.existsSync(), isFalse);
  });
}
