@TestOn('vm')
library;

import 'dart:io';

import 'package:apex_file_share/features/receive/data/sender_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// A line belongs to the file it was made for: a file of another size at the
/// same path (the first deleted outside the app, another saved as it) does
/// not show it.
void main() {
  final fingerprint = 'a' * 64;

  late Directory root;
  late File file;
  late File logFile;

  setUp(() {
    root = Directory.systemTemp.createTempSync('apex_sender_replaced_');
    file = File('${root.path}/Documents/report.pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3, 4]);
    logFile = File('${root.path}/app/senders.json');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('the same file keeps its line, after the log is read again', () async {
    final log = await SenderLog.open(logFile)
      ..record(file.path, name: 'Ali Phone', fingerprint: fingerprint);
    await log.saved;

    expect(log.of(file.path)?.name, 'Ali Phone');
    expect((await SenderLog.open(logFile)).of(file.path)?.name, 'Ali Phone');
  });

  test('a file of another size put at the same path shows no line, and the line is cleaned', () async {
    final log = await SenderLog.open(logFile)
      ..record(file.path, name: 'Ali Phone', fingerprint: fingerprint);
    await log.saved;

    file
      ..deleteSync()
      ..writeAsBytesSync([1, 2, 3, 4, 5, 6]);

    expect(log.of(file.path), isNull);
    await log.saved;
    expect((await SenderLog.open(logFile)).of(file.path), isNull);
    expect(logFile.readAsStringSync(), isNot(contains('Ali Phone')));
  });

  test('prune drops the line of a replaced file and keeps the others', () async {
    final other = File('${root.path}/Documents/notes.txt')..writeAsBytesSync([9]);
    final log = await SenderLog.open(logFile)
      ..record(file.path, name: 'Ali Phone', fingerprint: fingerprint)
      ..record(other.path, name: 'Sara Phone', fingerprint: fingerprint);
    await log.saved;
    file.writeAsBytesSync([1]);

    log.prune();
    await log.saved;

    final reopened = await SenderLog.open(logFile);
    expect(reopened.of(file.path), isNull);
    expect(reopened.of(other.path)?.name, 'Sara Phone');
  });

  test('a line written before sizes were kept matches no file', () async {
    logFile
      ..createSync(recursive: true)
      ..writeAsStringSync(
          '{"lines": {"${file.path.replaceAll(r'\', '/')}": {"name": "Ali Phone", "at": "2026-11-03T14:20:00.000Z", "key": "$fingerprint"}}}');

    final log = await SenderLog.open(logFile);

    expect(log.of(file.path), isNull);
  });
}
