import 'dart:convert';
import 'dart:math';

import '../../../core/protocol/transfer_rules.dart';
import 'offer.dart';

/// Issues one single-use token per accepted file, bound to the sender's real
/// address. An upload without a valid token writes nothing.
class ReceiveGate {
  ReceiveGate({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _clock;
  final _tickets = <String, _Ticket>{};

  /// Call only after the user accepted [offer]. Tokens follow the file order.
  List<String> admit(Offer offer) {
    _dropExpired();
    final batch = _Batch(offer.senderAddress, _clock());
    return [
      for (final file in offer.files) _issue(_Ticket(batch, file)),
    ];
  }

  /// The accepted file for [token], once. Null for a missing, unknown, used or
  /// expired token, or one sent from another address.
  OfferedFile? claim(String? token, String senderAddress) {
    final upload = take(token, senderAddress);
    upload?.finish();
    return upload?.file;
  }

  /// Like [claim], with a handle on the batch for the upload that follows.
  Upload? take(String? token, String senderAddress) {
    final ticket = _tickets[token];
    if (ticket == null || ticket.batch.address != senderAddress) {
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

  void _revoke(_Batch batch) => _tickets.removeWhere((_, t) => identical(t.batch, batch));

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

  void _dropExpired() => _tickets.removeWhere((_, t) => _isExpired(t.batch));
}

/// One accepted file being received.
class Upload {
  Upload._(this._gate, this._batch, this.file);

  final ReceiveGate _gate;
  final _Batch _batch;
  final OfferedFile file;

  bool _finished = false;

  /// The receiving user cancelled: no other file of this batch is accepted.
  void revokeBatch() => _gate._revoke(_batch);

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
  _Batch(this.address, this.lastUse);
  final String address;
  DateTime lastUse;
  int moving = 0;
}

class _Ticket {
  _Ticket(this.batch, this.file);
  final _Batch batch;
  final OfferedFile file;
}
