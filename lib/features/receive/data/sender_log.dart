import 'dart:convert';
import 'dart:io';

import '../../../platform/owner_only.dart';
import '../../identity/fingerprint.dart';

/// Who sent a received file: the name it gave when the file arrived, when,
/// and the fingerprint of the certificate it showed, which it cannot borrow
/// from a colleague as it can a name or an id.
typedef SenderLine = ({String name, DateTime at, String fingerprint});

/// One line per received file, by the path the file was placed at, for as
/// long as that same file is there: a line is kept with the file's size, and
/// a file of another size at the path (the first one deleted outside the app
/// and another saved under its name) does not wear it. Never a message's text.
///
/// Kept in one file in the app's own folder, written whole to a temp file
/// then renamed, so a crash mid-write leaves the old file. A file that
/// cannot be read is taken as an empty log, and the next write replaces it.
class SenderLog {
  /// In memory until [useFile].
  SenderLog.memory({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  File? _file;
  final _lines = <String, _Entry>{};
  Future<void> _writing = Future.value();

  static Future<SenderLog> open(File file, {DateTime Function()? clock}) async {
    final log = SenderLog.memory(clock: clock);
    await log.useFile(file);
    return log;
  }

  /// From now on kept in [file]: its lines are read, and every change is
  /// written there.
  Future<void> useFile(File file) async {
    if (_file?.path == file.path) {
      return;
    }
    final read = <String, _Entry>{};
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        final stored = json is Map ? json['lines'] : null;
        if (stored is Map) {
          for (final e in stored.entries) {
            final entry = _parse(e.value);
            if (e.key is String && entry != null) {
              read[e.key as String] = entry;
            }
          }
        }
      }
    } catch (_) {
      read.clear();
    }
    // A line made before the file was read is the newer one.
    _lines.addAll({...read, ..._lines});
    _file = file;
  }

  /// Call once the file is complete at [path], where it stays. A line an
  /// older file at that path left is replaced.
  void record(String path, {required String name, required String fingerprint}) {
    final key = _key(path);
    _lines[key] = _Entry((name: name, at: _clock().toUtc(), fingerprint: fingerprint), _sizeOf(key));
    _save();
  }

  /// The line of the file at [path]; null when it has none, or when the file
  /// is gone or is not the one the line was made for (deleted and replaced
  /// outside the app), whose line is then dropped.
  SenderLine? of(String path) {
    final key = _key(path);
    final entry = _lines[key];
    if (entry == null) {
      return null;
    }
    if (_sizeOf(key) != entry.size) {
      _lines.remove(key);
      _save();
      return null;
    }
    return entry.line;
  }

  /// The app deleted or moved the file at [path].
  void forget(String path) {
    if (_lines.remove(_key(path)) != null) {
      _save();
    }
  }

  /// Drops the line of every file that is gone.
  void prune() {
    final before = _lines.length;
    _lines.removeWhere((key, entry) => _sizeOf(key) != entry.size);
    if (_lines.length != before) {
      _save();
    }
  }

  /// Done once every change so far is on disk.
  Future<void> get saved => _writing;

  /// One spelling per file: "/" and "\" both reach it on Windows, and the
  /// path a file was placed at and the one a folder listing gives differ in it.
  static String _key(String path) => path.replaceAll(r'\', '/');

  /// -1 when there is no file, which no line matches.
  static int _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } on FileSystemException {
      return -1;
    }
  }

  static _Entry? _parse(Object? v) {
    if (v is! Map) {
      return null;
    }
    final name = v['name'];
    final at = v['at'] is String ? DateTime.tryParse(v['at'] as String) : null;
    final fingerprint = v['key'];
    if (name is! String || at == null || !isFingerprint(fingerprint)) {
      return null;
    }
    // A line without a size is from before sizes were kept: it matches no file.
    final size = v['size'];
    return _Entry((name: name, at: at, fingerprint: fingerprint as String), size is int ? size : -1);
  }

  void _save() {
    // One write at a time, each with every line so far.
    _writing = _writing.then((_) => _write()).catchError((_) {});
  }

  Future<void> _write() async {
    final file = _file;
    if (file == null) {
      return;
    }
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    final lines = {
      for (final e in _lines.entries)
        e.key: {
          'name': e.value.line.name,
          'at': e.value.line.at.toIso8601String(),
          'key': e.value.line.fingerprint,
          'size': e.value.size,
        },
    };
    await part.writeAsString(jsonEncode({'lines': lines}), flush: true);
    await keepOwnerOnly(part);
    await part.rename(file.path);
  }
}

class _Entry {
  const _Entry(this.line, this.size);

  final SenderLine line;
  final int size;
}
