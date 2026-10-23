import 'dart:io';

/// Moves [source] into [folder] as [name] without ever replacing what is there:
/// an existing "report.txt" makes the new one "report_1.txt", then "report_2.txt".
///
/// `rename` alone is not safe: on Linux it replaces the target, and on Windows
/// it fails and a `copy` fallback would replace it. So the free name is found
/// first, and moves run one at a time so two of them never pick the same name.
Future<File> moveIntoFolder(File source, Directory folder, String name) =>
    _oneAtATime(() => _move(source, folder, name));

Future<File> _move(File source, Directory folder, String name) async {
  await folder.create(recursive: true);
  final target = File(_freePath(folder.path, name));
  try {
    return await source.rename(target.path);
  } on FileSystemException {
    // Another drive: copy, then remove the source.
  }
  try {
    await source.copy(target.path);
  } catch (_) {
    // The target did not exist before, so a half copy is ours to remove.
    if (await target.exists()) {
      await target.delete();
    }
    rethrow;
  }
  try {
    await source.delete();
  } catch (_) {
    // The full copy is in place; a leftover source is only a temp file.
  }
  return target;
}

String _freePath(String folder, String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  var candidate = '$folder${Platform.pathSeparator}$name';
  for (var n = 1; FileSystemEntity.typeSync(candidate) != FileSystemEntityType.notFound; n++) {
    candidate = '$folder${Platform.pathSeparator}${base}_$n$ext';
  }
  return candidate;
}

Future<void> _tail = Future.value();

Future<T> _oneAtATime<T>(Future<T> Function() job) {
  final result = _tail.then((_) => job());
  _tail = result.then((_) {}, onError: (_) {});
  return result;
}
