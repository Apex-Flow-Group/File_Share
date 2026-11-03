import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/files/move_into_folder.dart';
import 'package:apex_file_share/core/files/save_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory tempRoot;
  late Directory folder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('apex_download_test_');
    tempRoot = Directory('${root.path}/tmp')..createSync();
    folder = Directory('${root.path}/save')..createSync();
  });

  tearDown(() => root.delete(recursive: true));

  Future<String> intoFolder(File temp, String name) async =>
      (await moveIntoFolder(temp, folder, name)).path;

  Stream<List<int>> bytes(String text) => Stream.value(utf8.encode(text));

  List<String> under(Directory d) => d
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.substring(d.path.length + 1))
      .toList();

  test('a name that climbs with ../ stays inside the save folder', () async {
    final saved = await saveDownload(bytes('x'), '../../evil.bat',
        tempRoot: tempRoot, place: intoFolder);
    expect(File(saved).parent.path, folder.path);
    expect(under(root).where((p) => !p.startsWith('save')), isEmpty);
  });

  test('a name the remote side never cleaned is cleaned', () async {
    final saved = await saveDownload(bytes('x'), 'notes: draft?.txt',
        tempRoot: tempRoot, place: intoFolder);
    expect(File(saved).uri.pathSegments.last, 'notes_ draft_.txt');
  });

  test('an existing file is never replaced', () async {
    File('${folder.path}/report.txt').writeAsStringSync('mine');
    final saved = await saveDownload(bytes('theirs'), 'report.txt',
        tempRoot: tempRoot, place: intoFolder);
    expect(File('${folder.path}/report.txt').readAsStringSync(), 'mine');
    expect(File(saved).uri.pathSegments.last, 'report_1.txt');
  });

  test('a cut connection leaves no half file anywhere', () async {
    final body = StreamController<List<int>>();
    final saving = saveDownload(body.stream, 'big.bin', tempRoot: tempRoot, place: intoFolder);
    body.add(List.filled(100, 1));
    body.addError(const SocketException('connection reset'));
    unawaited(body.close());
    await expectLater(saving, throwsA(isA<SocketException>()));
    expect(under(root), isEmpty);
  });

  test('the temp copy is gone once the file is placed', () async {
    await saveDownload(bytes('x'), 'a.txt', tempRoot: tempRoot, place: intoFolder);
    expect(tempRoot.listSync(), isEmpty);
  });
}
