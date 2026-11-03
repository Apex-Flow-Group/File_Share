import 'dart:io';

import 'package:apex_file_share/platform/free_space.dart';
import 'package:flutter_test/flutter_test.dart';

/// The receiver refuses a batch bigger than its free space before any byte is
/// written, but only if the free space is read. Without a reading the check
/// is skipped and the disk fills mid-transfer.
void main() {
  test('Linux: the free space read matches df', () async {
    final dir = Directory.systemTemp.path;
    final df = await Process.run('df', ['--output=avail', '-B1', dir]);
    final expected = int.parse((df.stdout as String).trim().split('\n').last.trim());

    final read = await freeBytesAt(dir);

    expect(read, isNotNull);
    // Other programs write meanwhile: allow 1% or 64 MB.
    final slack = [expected ~/ 100, 64 << 20].reduce((a, b) => a > b ? a : b);
    expect((read! - expected).abs(), lessThanOrEqualTo(slack), reason: 'read $read, df $expected');
  }, testOn: 'linux');

  test('a path that does not exist gives no reading, not a wrong one', () async {
    expect(await freeBytesAt('${Directory.systemTemp.path}/apex-no-such-folder/x'), isNull);
  }, testOn: 'linux || windows');

  test('the receiver is given the free space of the save folder', () {
    final core = File('lib/core/apex_core.dart').readAsStringSync();
    final receive = RegExp(r'ReceiveHttp\(([\s\S]*?)\n  \);').firstMatch(core)?.group(1);
    expect(receive, isNotNull, reason: 'ReceiveHttp is no longer built in apex_core.dart; update this test.');
    expect(receive, contains('freeBytes:'), reason: 'The free-space check never runs in the app.');
  });
}
