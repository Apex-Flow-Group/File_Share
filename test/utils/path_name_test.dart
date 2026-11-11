import 'package:apex_file_share/utils/path_name.dart';
import 'package:flutter_test/flutter_test.dart';

/// The name shown for a file or folder is the same whichever slash the path
/// has, and a path on Windows may have both.
void main() {
  test('a Windows path and a Unix path give the same name', () {
    expect(fileNameOf(r'C:\Users\sam\Documents\ApexShare\Images\photo 1.png'), 'photo 1.png');
    expect(fileNameOf('/home/sam/Downloads/ApexShare/Images/photo 1.png'), 'photo 1.png');
  });

  test('a path joined from both slashes gives the name, not the tail of the path', () {
    expect(fileNameOf(r'C:\Users\sam\Documents/ApexShare/Share/report.pdf'), 'report.pdf');
  });

  test('a category folder is named by its last part', () {
    expect(fileNameOf(r'C:\Users\sam\Documents\ApexShare\Images'), 'Images');
    expect(fileNameOf('/home/sam/ApexShare/Images/'), 'Images');
    expect(fileNameOf(r'C:\Users\sam\ApexShare\Images\'), 'Images');
  });

  test('a bare name stays, and a root or a drive has none', () {
    expect(fileNameOf('a.txt'), 'a.txt');
    expect(fileNameOf(''), '');
    expect(fileNameOf('/'), '');
    expect(fileNameOf(r'C:\'), '');
    expect(fileNameOf('C:'), '');
  });
}
