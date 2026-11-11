import 'dart:convert';
import 'dart:math';

import '../../../core/protocol/transfer_rules.dart';
import '../../chat/logic/chat_key.dart';
import 'offer.dart';

/// Issues one single-use token per accepted file, bound to the sender's real
/// address and its certificate. An upload without a valid token writes nothing.
class ReceiveGate {
  ReceiveGate({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _clock;
  final _tickets = <String, _Ticket>{};

  /// Every batch not yet expired, including one whose last file is moving
  /// and so has no token left.
  final _batches = <_Batch>{};
  var _nextBatch = 0;

  /// Call only after the user accepted [offer]. Tokens follow the file order.
  List<String> admit(Offer offer) {
    _dropExpired();
    final batch = _Batch(offer.senderAddress, offer.senderFingerprint, _clock(), _nextBatch++,
        offer.senderName, offer.senderId);
    _batches.add(batch);
    return [
      for (final file in offer.files) _issue(_Ticket(batch, file)),
    ];
  }

  /// The accepted file for [token], once. Null for a missing, unknown, used or
  /// expired token, or one sent from another address or certificate.
  OfferedFile? claim(String? token, String senderAddress, String fingerprint) {
    final upload = take(token, senderAddress, fingerprint);
    upload?.finish();
    return upload?.file;
  }

  /// Like [claim], with a handle on the batch for the upload that follows.
  Upload? take(String? token, String senderAddress, String fingerprint) {
    final ticket = _tickets[token];
    if (ticket == null || ticket.batch.address != senderAddress || ticket.batch.fingerprint != fingerprint) {
      return null;
    }
    if (_isExpired(ticket.batch)) {
      _dropExpired();
      return null;
    }
    _tickets.remove(token);
    ticket.batch
      ..lastUse = _clock()
      ..moving += 1;
    return Upload._(this, ticket.batch, ticket.file);
  }

  /// Ends every batch whose sender [turnedAway] now refuses: none of its
  /// tokens is accepted again, and a file of it moving now stops.
  void revokeWhere(bool Function(ChatPeer sender) turnedAway) {
    for (final b in _batches.where((b) => turnedAway(chatPeer(b.fingerprint, b.senderId, b.address))).toList()) {
      _revoke(b);
    }
  }

  void _revoke(_Batch batch) {
    batch.revoked = true;
    _batches.remove(batch);
    _tickets.removeWhere((_, t) => identical(t.batch, batch));
  }

  String _issue(_Ticket ticket) {
    String token;
    do {
      token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));
    } while (_tickets.containsKey(token));
    _tickets[token] = ticket;
    return token;
  }

  /// Idle means no file of the batch is moving: a big file may take longer
  /// than the limit, and the files after it must still be accepted.
  bool _isExpired(_Batch b) =>
      b.moving == 0 && _clock().difference(b.lastUse) > TransferRules.tokenIdleLimit;

  void _dropExpired() {
    _tickets.removeWhere((_, t) => _isExpired(t.batch));
    _batches.removeWhere(_isExpired);
  }
}

/// One accepted file being received.
class Upload {
  Upload._(this._gate, this._batch, this.file);

  final ReceiveGate _gate;
  final _Batch _batch;
  final OfferedFile file;

  /// Tells this file's batch from any other, even one accepted meanwhile.
  int get batchId => _batch.id;

  /// The name its sender gave in the offer the user accepted.
  String get senderName => _batch.senderName;

  /// The id its sender gave in that offer.
  String get senderId => _batch.senderId;

  /// The fingerprint of the certificate that offer came with.
  String get senderFingerprint => _batch.fingerprint;

  bool _finished = false;

  /// The receiving user cancelled: no other file of this batch is accepted.
  void revokeBatch() => _gate._revoke(_batch);

  /// The batch was ended while this file moved: its sender was blocked.
  bool get revoked => _batch.revoked;

  /// Call once the upload ends, however it ends. The idle time counts from here.
  void finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _batch
      ..moving -= 1
      ..lastUse = _gate._clock();
  }
}

class _Batch {
  _Batch(this.address, this.fingerprint, this.lastUse, this.id, this.senderName, this.senderId);
  final String address;
  final String fingerprint;
  final int id;
  final String senderName;
  final String senderId;
  DateTime lastUse;
  int moving = 0;
  bool revoked = false;
}

class _Ticket {
  _Ticket(this.batch, this.file);
  final _Batch batch;
  final OfferedFile file;
}
