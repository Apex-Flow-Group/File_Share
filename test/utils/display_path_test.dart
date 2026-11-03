import 'package:apex_file_share/utils/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lri = String.fromCharCode(0x2066);
  final pdi = String.fromCharCode(0x2069);

  test('the Android storage root is not shown', () {
    expect(FileUtils.displayPath('/storage/emulated/0/Download/ApexShare/Documents/report_1.txt'),
        '${lri}Download/ApexShare/Documents/report_1.txt$pdi');
  });

  test('a path keeps left-to-right order inside an Arabic sentence', () {
    final shown = FileUtils.displayPath('/home/u/Documents/ApexShare/Downloads/a.txt');
    expect(shown.startsWith(lri) && shown.endsWith(pdi), isTrue,
        reason: 'Without the isolate the leading "/" jumps to the other end in RTL text.');
  });
}
