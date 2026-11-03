import 'dart:convert';
import 'dart:io';

/// Moves [source] into [folder] as [name] without ever replacing what is there:
/// an existing "report.txt" makes the new one "report_1.txt", then "report_2.txt".
///
/// `rename` alone is not safe: Dart's rename replaces an existing target on
/// every system, and so would the `copy` fallback. So the free name is found
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
  final hasExt = dot > 0 && name.length - dot <= 16;
  final base = hasExt ? name.substring(0, dot) : name;
  final ext = hasExt ? name.substring(dot) : '';
  var candidate = '$folder${Platform.pathSeparator}$name';
  for (var n = 1; FileSystemEntity.typeSync(candidate) != FileSystemEntityType.notFound; n++) {
    candidate = '$folder${Platform.pathSeparator}${_fit(base, '_$n$ext')}';
  }
  return candidate;
}

/// A name already at the limit must still fit once "_1" is added, or the
/// move fails and the received file is lost. Linux counts UTF-8 bytes;
/// Windows counts UTF-16 units, which are never more than the bytes.
const _maxNameBytes = 255;

/// [base] shortened by whole characters so that [base] + [tail] fits.
String _fit(String base, String tail) {
  final room = _maxNameBytes - utf8.encode(tail).length;
  final runes = base.runes.toList();
  while (runes.isNotEmpty && utf8.encode(String.fromCharCodes(runes)).length > room) {
    runes.removeLast();
  }
  return '${String.fromCharCodes(runes)}$tail';
}

Future<void> _tail = Future.value();

Future<T> _oneAtATime<T>(Future<T> Function() job) {
  final result = _tail.then((_) => job());
  _tail = result.then((_) {}, onError: (_) {});
  return result;
}
