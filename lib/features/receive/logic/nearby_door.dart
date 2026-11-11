import 'dart:async';

import '../../../core/core_models.dart';
import '../../../core/files/safe_file_name.dart';
import '../../../core/one_question.dart';
import '../../../core/protocol/apex_protocol.dart';
import '../../../core/protocol/nearby_messages.dart';
import '../../../core/protocol/transfer_rules.dart';
import '../../../core/text/clean_label.dart';
import '../../../models/device.dart';
import 'offer.dart';
import 'receive_gate.dart';

/// The Nearby receiving door, kept apart from the plugin so it can be tested.
/// A phone is connected only after the user agrees, and a FILE payload is kept
/// only when it was announced with a token the user's acceptance issued.
class NearbyDoor {
  NearbyDoor({
    required this.onConnectionRequest,
    required this.send,
    this.onAdmitted,
    this.freeBytes,
    ReceiveGate? gate,
    OneQuestion? question,
    this.decisionTimeout = TransferRules.decisionTimeout,
    this.announceWait = const Duration(seconds: 10),
  })  : _gate = gate ?? ReceiveGate(),
        _question = question ?? OneQuestion();

  final void Function(ConnectionRequest) onConnectionRequest;
  final Future<void> Function(String endpointId, Map<String, Object?> msg) send;
  final void Function(Offer)? onAdmitted;

  /// Free space where files are saved; null when it cannot be read.
  final Future<int?> Function()? freeBytes;
  final Duration decisionTimeout;

  /// A FILE payload and its announcement are separate payloads and may arrive
  /// in either order.
  final Duration announceWait;

  final ReceiveGate _gate;
  final _names = <String, String>{};
  final _tokens = <String, Set<String>>{};
  final _bound = <(String, int), OfferedFile>{};
  final _waiting = <(String, int), Completer<OfferedFile?>>{};
  final _lastUse = <String, DateTime>{};
  final OneQuestion _question;

  /// Asks the user before a phone may connect at all.
  Future<bool> mayConnect(String endpointId, String endpointName) {
    final name = cleanLabel(endpointName);
    _names[endpointId] = name.isEmpty ? endpointId : name;
    return _ask((respond) => ConnectionRequest(
          device: _device(endpointId),
          fileName: '',
          fileCount: 0,
          kind: RequestKind.connect,
          onResponse: respond,
        ));
  }

  Future<void> onMessage(String endpointId, Object? msg) async {
    if (msg is! Map) {
      return;
    }
    switch (msg['type']) {
      case NearbyMessage.offer:
        await _offer(endpointId, msg);
      case NearbyMessage.file:
        _announce(endpointId, msg);
    }
  }

  /// False when no accepted file from [endpointId] is still to come, so a
  /// FILE payload can be cancelled before more of it is written.
  bool expectsFile(String endpointId) {
    final last = _lastUse[endpointId];
    if (last == null || DateTime.now().difference(last) > TransferRules.tokenIdleLimit) {
      return false;
    }
    return (_tokens[endpointId]?.isNotEmpty ?? false) || _bound.keys.any((k) => k.$1 == endpointId);
  }

  /// The accepted file of a payload still arriving, for its progress line.
  OfferedFile? announced(String endpointId, int payloadId) => _bound[(endpointId, payloadId)];

  /// The accepted file for a finished payload, once; null means drop it.
  Future<OfferedFile?> takeFile(String endpointId, int payloadId) async {
    final key = (endpointId, payloadId);
    final bound = _bound.remove(key);
    if (bound != null) {
      return bound;
    }
    final waiter = _waiting[key] = Completer<OfferedFile?>();
    try {
      return await waiter.future.timeout(announceWait, onTimeout: () => null);
    } finally {
      _waiting.remove(key);
    }
  }

  /// The connection is gone, or the user cancelled: nothing more comes in.
  void forget(String endpointId) {
    _names.remove(endpointId);
    _tokens.remove(endpointId);
    _lastUse.remove(endpointId);
    _bound.removeWhere((k, _) => k.$1 == endpointId);
    for (final key in _waiting.keys.where((k) => k.$1 == endpointId).toList()) {
      _waiting.remove(key)!.complete(null);
    }
  }

  // ─── Offer ─────────────────────────────────────────────────────────────────

  Future<void> _offer(String endpointId, Map msg) async {
    if (msg['version'] != ApexProtocol.version) {
      await _answer(endpointId,
          {'accepted': false, 'error': ApexProtocol.updateRequired, 'version': ApexProtocol.version});
      return;
    }
    final offer = _parse(endpointId, msg);
    if (offer == null) {
      await _answer(endpointId, {'accepted': false, 'error': 'bad_offer'});
      return;
    }
    final problem = checkOffer(offer, freeBytes: await freeBytes?.call());
    if (problem != null) {
      await _answer(endpointId, {'accepted': false, 'error': problem.name});
      return;
    }
    final accepted = await _ask((respond) => ConnectionRequest(
          device: _device(endpointId, offer.senderName),
          fileName: offer.files.first.name,
          fileSize: offer.totalBytes,
          fileCount: offer.files.length,
          fileNames: [for (final f in offer.files) f.name],
          onResponse: respond,
        ));
    if (!accepted) {
      await _answer(endpointId, {'accepted': false});
      return;
    }
    final tokens = _gate.admit(offer);
    (_tokens[endpointId] ??= {}).addAll(tokens);
    _lastUse[endpointId] = DateTime.now();
    onAdmitted?.call(offer);
    await _answer(endpointId, {'accepted': true, 'tokens': tokens});
  }

  /// Names are cleaned here, once; the announcement's own name is never used.
  Offer? _parse(String endpointId, Map msg) {
    final files = msg['files'];
    if (files is! List) {
      return null;
    }
    final parsed = <OfferedFile>[];
    for (final f in files) {
      final size = f is Map ? f['size'] : null;
      if (size is! int) {
        return null;
      }
      final name = f['name'];
      parsed.add(OfferedFile(safeFileName(name is String ? name : null), size));
    }
    final rawName = msg['name'];
    final claimed = cleanLabel(rawName is String ? rawName : null);
    return Offer(
      senderAddress: endpointId,
      // Nearby has no chat: the endpoint is all there is to tell it by.
      senderId: endpointId,
      // The name shown when the user agreed to connect wins over a new claim.
      senderName: _names[endpointId] ?? (claimed.isEmpty ? endpointId : claimed),
      files: parsed,
    );
  }

  Future<void> _answer(String endpointId, Map<String, Object?> body) =>
      send(endpointId, {'type': NearbyMessage.answer, ...body});

  // ─── Announcement ──────────────────────────────────────────────────────────

  void _announce(String endpointId, Map msg) {
    final id = msg['payload_id'];
    final token = msg['token'];
    if (id is! int || token is! String || !(_tokens[endpointId]?.remove(token) ?? false)) {
      return;
    }
    final file = _gate.claim(token, endpointId);
    if (file == null) {
      return;
    }
    _lastUse[endpointId] = DateTime.now();
    final key = (endpointId, id);
    final waiter = _waiting.remove(key);
    if (waiter != null) {
      waiter.complete(file);
    } else {
      _bound[key] = file;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _ask(ConnectionRequest Function(void Function(bool) respond) build) async {
    if (!_question.take()) {
      return false;
    }
    final answer = Completer<bool>();
    final request = build((v) {
      if (!answer.isCompleted) {
        answer.complete(v);
      }
    });
    try {
      onConnectionRequest(request);
      return await answer.future.timeout(decisionTimeout, onTimeout: () => false);
    } finally {
      _question.release();
      request.close();
    }
  }

  Device _device(String endpointId, [String? name]) => Device(
        id: 'nearby:$endpointId',
        name: name ?? _names[endpointId] ?? endpointId,
        type: 'phone',
        endpointId: endpointId,
      );
}
