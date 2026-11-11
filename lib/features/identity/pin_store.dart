import 'dart:convert';
import 'dart:io';

import '../../platform/owner_only.dart';
import 'fingerprint.dart';

/// The fingerprint each device id had when the user last accepted it (a chat,
/// a file batch or the shared folder). A known id that comes back with another
/// fingerprint is not that device until the user accepts it again.
///
/// Identity only: ids and fingerprints, never a name or a message.
class PinStore {
  /// In memory until [useFile].
  PinStore.memory();

  File? _file;
  final _pins = <String, String>{};
  Future<void> _writing = Future.value();

  static Future<PinStore> open(File file) async {
    final store = PinStore.memory();
    await store.useFile(file);
    return store;
  }

  /// From now on kept in [file]: its pins are read, and every pin is written
  /// there. A missing or unreadable file starts with no pins.
  Future<void> useFile(File file) async {
    if (_file?.path == file.path) {
      return;
    }
    final read = <String, String>{};
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        final stored = json is Map ? json['pins'] : null;
        if (stored is Map) {
          for (final e in stored.entries) {
            if (e.key is String && isFingerprint(e.value)) {
              read[e.key as String] = e.value as String;
            }
          }
        }
      }
    } on Exception {
      read.clear();
    }
    // A pin made before the file was read is the newer answer.
    _pins.addAll({...read, ..._pins});
    _file = file;
  }

  String? pinned(String id) => _pins[id];

  /// [id] was accepted before with another fingerprint.
  bool keyChanged(String id, String fingerprint) {
    final known = _pins[id];
    return known != null && known != fingerprint;
  }

  /// The user accepted [id] holding [fingerprint].
  Future<void> pin(String id, String fingerprint) {
    if (_pins[id] == fingerprint) {
      return _writing;
    }
    _pins[id] = fingerprint;
    // One write at a time, each with every pin so far.
    return _writing = _writing.then((_) => _save()).catchError((_) {});
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) {
      return;
    }
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    await part.writeAsString(jsonEncode({'pins': _pins}), flush: true);
    await keepOwnerOnly(part);
    await part.rename(file.path);
  }
}
