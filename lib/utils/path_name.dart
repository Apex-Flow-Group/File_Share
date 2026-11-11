/// The last part of a file or folder path, whichever slash it uses: a path
/// on Windows has "\" and often "/" in the same string (a folder joined with
/// "/" to a path the system gave with "\"). Empty for a bare drive or root.
String fileNameOf(String path) {
  var end = path.length;
  while (end > 0 && _isSlash(path.codeUnitAt(end - 1))) {
    end--;
  }
  var start = end;
  while (start > 0 && !_isSlash(path.codeUnitAt(start - 1))) {
    start--;
  }
  final name = path.substring(start, end);
  // "C:" is a drive, not a name.
  return start == 0 && name.length == 2 && name.endsWith(':') ? '' : name;
}

bool _isSlash(int unit) => unit == 0x2F || unit == 0x5C;
