import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/services/folder_zip_service.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory tempRoot;

  setUp(() {
    root = Directory.systemTemp.createTempSync('apex_zip_test_');
    tempRoot = Directory('${root.path}/tmp')..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Relative path -> bytes for files, null for folders. Separators are '/'
  /// as in a zip entry, also on Windows.
  Map<String, List<int>?> tree(Directory dir) => {
        for (final e in dir.listSync(recursive: true, followLinks: false))
          e.path.substring(dir.path.length + 1).replaceAll(r'\', '/'):
              e is File ? e.readAsBytesSync() : null,
      };

  Directory makeFolder() {
    final dir = Directory('${root.path}/رحلة')..createSync();
    File('${dir.path}/notes.txt').writeAsStringSync('hello');
    File('${dir.path}/empty.txt').writeAsBytesSync([]);
    Directory('${dir.path}/صور').createSync();
    File('${dir.path}/صور/صورة.jpg').writeAsBytesSync(List.generate(5000, (i) => i % 251));
    Directory('${dir.path}/فارغ').createSync();
    return dir;
  }

  test('what comes out of the zip is the folder as it was', () async {
    final folder = makeFolder();
    final zipPath = await FolderZipService.zipFolder(folder.path, tempRoot: tempRoot);

    // Read the entries directly: the package's extractArchiveToDisk skips
    // empty folders, which would hide whether they are in the zip.
    final input = InputFileStream(zipPath);
    final unzipped = {
      for (final f in ZipDecoder().decodeStream(input).files)
        f.name.substring('رحلة/'.length).replaceFirst(RegExp(r'/$'), ''):
            f.isFile ? f.content.toList() : null,
    };
    await input.close();

    expect(unzipped, tree(folder),
        reason: 'an empty file, a subfolder, an empty folder and Arabic names');
  });

  test('folder entries are stored, so strict unzip tools accept them', () async {
    final zipPath = await FolderZipService.zipFolder(makeFolder().path, tempRoot: tempRoot);
    final bytes = File(zipPath).readAsBytesSync();
    final methods = <String, int>{};
    // Central directory records: "PK\x01\x02", method at +10, name length at +28.
    for (var i = 0; i + 46 <= bytes.length; i++) {
      if (bytes[i] == 0x50 && bytes[i + 1] == 0x4b && bytes[i + 2] == 1 && bytes[i + 3] == 2) {
        final method = bytes[i + 10] | bytes[i + 11] << 8;
        final nameLength = bytes[i + 28] | bytes[i + 29] << 8;
        methods[utf8.decode(bytes.sublist(i + 46, i + 46 + nameLength))] = method;
      }
    }
    expect(methods.length, 5);
    expect(methods.values.toSet(), {0},
        reason: 'A folder marked "deflated" with no data fails "unzip -t": $methods');
  });

  test('memory does not grow with the folder', () async {
    final folder = Directory('${root.path}/big')..createSync();
    const size = 400 * 1024 * 1024;
    // Sparse: created at once, but read back as 400 MB of zeros.
    File('${folder.path}/video.bin').openSync(mode: FileMode.write)
      ..setPositionSync(size - 1)
      ..writeByteSync(0)
      ..closeSync();

    final before = ProcessInfo.maxRss;
    final zipPath = await FolderZipService.zipFolder(folder.path, tempRoot: tempRoot);
    final grew = ProcessInfo.maxRss - before;

    expect(grew, lessThan(100 * 1024 * 1024),
        reason: 'peak memory grew by ${grew ~/ (1024 * 1024)} MB for a 400 MB file');
    expect(File(zipPath).lengthSync(), greaterThan(size), reason: 'stored, not compressed');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a failed zip leaves no partial file behind', () async {
    final folder = makeFolder();
    final locked = File('${folder.path}/locked.txt')..writeAsStringSync('x');
    Process.runSync('chmod', ['000', locked.path]);
    addTearDown(() => Process.runSync('chmod', ['600', locked.path]));

    await expectLater(FolderZipService.zipFolder(folder.path, tempRoot: tempRoot), throwsA(anything));
    expect(tempRoot.listSync(recursive: true), isEmpty);
  }, testOn: 'linux || mac-os');

  test('a zip left by a crash is removed by the next zip, a recent one is not', () async {
    final old = Directory('${tempRoot.path}/apex_zip_old')..createSync();
    File('${old.path}/half.zip').writeAsStringSync('x');
    Process.runSync('touch', ['-d', '2 days ago', old.path]);
    final recent = Directory('${tempRoot.path}/apex_zip_recent')..createSync();

    await FolderZipService.zipFolder(makeFolder().path, tempRoot: tempRoot);
    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue, reason: 'it may be a zip still being written');
  }, testOn: 'linux || mac-os');

  test('cleanup removes the zip and its folder', () async {
    final zipPath = await FolderZipService.zipFolder(makeFolder().path, tempRoot: tempRoot);
    await FolderZipService.cleanupTemp(zipPath);
    expect(tempRoot.listSync(), isEmpty);
  });

  test('a link inside the folder is not followed out of it', () async {
    final folder = makeFolder();
    final secret = File('${root.path}/secret.txt')..writeAsStringSync('private');
    Link('${folder.path}/shortcut').createSync(secret.path);

    final zipPath = await FolderZipService.zipFolder(folder.path, tempRoot: tempRoot);
    final input = InputFileStream(zipPath);
    final names = ZipDecoder().decodeStream(input).files.map((f) => f.name).toList();
    await input.close();
    expect(names.where((n) => n.contains('shortcut')), isEmpty);
  }, testOn: 'linux || mac-os');

  test('the zip is written where other users cannot read it', () async {
    final zipPath = await FolderZipService.zipFolder(makeFolder().path, tempRoot: tempRoot);
    expect(File(zipPath).parent.statSync().mode & 0x3F, 0);
  }, testOn: 'linux || mac-os');
}
