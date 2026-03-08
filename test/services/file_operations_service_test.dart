import 'dart:io';

import 'package:file_share_app/services/file_operations_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FileOperationsService service;
  late Directory testDir;

  setUp(() {
    service = FileOperationsService();
    testDir = Directory.systemTemp.createTempSync('apex_test_');
  });

  tearDown(() {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('FileOperationsService', () {
    test('deleteFiles removes existing files', () async {
      final file1 = File('${testDir.path}/test1.txt')..writeAsStringSync('test');
      final file2 = File('${testDir.path}/test2.txt')..writeAsStringSync('test');

      final count = await service.deleteFiles(
        {file1.path, file2.path},
        deleteFromFolder: true,
      );

      expect(count, 2);
      expect(file1.existsSync(), false);
      expect(file2.existsSync(), false);
    });

    test('deleteFiles handles non-existent files', () async {
      final count = await service.deleteFiles(
        {'${testDir.path}/nonexistent.txt'},
        deleteFromFolder: true,
      );

      expect(count, 0);
    });

    test('deleteFiles with deleteFromFolder=false counts without deleting', () async {
      final file = File('${testDir.path}/test.txt')..writeAsStringSync('test');

      final count = await service.deleteFiles(
        {file.path},
        deleteFromFolder: false,
      );

      expect(count, 1);
      expect(file.existsSync(), true);
    });
  });
}
