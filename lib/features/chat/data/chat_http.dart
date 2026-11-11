import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/core_models.dart';
import '../../../core/one_question.dart';
import '../../../core/protocol/apex_protocol.dart';
import '../../../core/protocol/transfer_rules.dart';
import '../../../core/text/clean_label.dart';
import '../../../models/device.dart';
import '../../identity/caller.dart';
import '../../identity/pin_store.dart';
import '../logic/block_list.dart';
import '../logic/chat_access.dart';
import '../logic/chat_key.dart';
import '../logic/chat_text.dart';

typedef IncomingChat = ({String id, String address, String fingerprint, String name, String text});

/// The chat door: POST /chat. The first message from a device (the id it
/// gives, with the certificate discovery heard from it at that address) asks
/// the user; once accepted, the reply carries a token bound to its
/// certificate, and later messages with it arrive without asking. Nothing is shown before the user agrees, so
/// a stranger cannot put text on the screen.
class ChatHttp {
  ChatHttp({
    required this.onRequest,
    required this.onMessage,
    required this.expectedFingerprint,
    required this.pins,
    this.onBlocked,
    ChatAccess? access,
    OneQuestion? question,
    this.decisionTimeout = TransferRules.decisionTimeout,
    this.bodyIdleLimit = TransferRules.bodyIdleLimit,
  })  : _access = access ?? ChatAccess(blocks: BlockList(pins)),
        _question = question ?? OneQuestion();

  final void Function(ConnectionRequest) onRequest;
  final void Function(IncomingChat) onMessage;
  final ExpectedFingerprint expectedFingerprint;

  /// Written when the user accepts a chat. Never a message.
  final PinStore pins;

  /// The user refused the question: the device is now blocked.
  final void Function(ChatPeer peer)? onBlocked;
  final Duration decisionTimeout;
  final Duration bodyIdleLimit;
  final ChatAccess _access;
  final OneQuestion _question;

  void block(ChatPeer peer) => _access.block(peer);

  void unblock(ChatPeer peer) => _access.unblock(peer);

  /// False when [req] is not for this door.
  Future<bool> handle(HttpRequest req) async {
    if (req.uri.path != ApexProtocol.chatPath) {
      return false;
    }
    final fingerprint = callerFingerprint(req);
    if (fingerprint == null || !ApexProtocol.accepts(req.headers.value(ApexProtocol.versionHeader))) {
      await _reply(req, HttpStatus.upgradeRequired,
          {'error': ApexProtocol.updateRequired, 'version': ApexProtocol.version});
      return true;
    }
    if (req.method != 'POST') {
      await _reply(req, HttpStatus.methodNotAllowed, {'error': 'method'});
      return true;
    }
    await _message(req, fingerprint);
    return true;
  }

  Future<void> _message(HttpRequest req, String fingerprint) async {
    final address = req.connectionInfo?.remoteAddress.address;
    final Object? body;
    try {
      body = await _readJson(req);
    } on TimeoutException {
      return;
    }
    if (body == _tooLong) {
      await _reply(req, HttpStatus.requestEntityTooLarge, {'error': ApexProtocol.tooLong});
      return;
    }
    final raw = body is Map ? body['text'] : null;
    if (raw is String && raw.runes.length > TransferRules.chatTextLimit) {
      await _reply(req, HttpStatus.requestEntityTooLarge, {'error': ApexProtocol.tooLong});
      return;
    }
    final text = cleanChatText(raw);
    final id = body is Map ? cleanDeviceId(body['id']) : null;
    if (address == null || body is! Map || text == null || id == null) {
      await _reply(req, HttpStatus.badRequest, {'error': 'bad_message'});
      return;
    }
    if (expectedFingerprint(id, address) != fingerprint) {
      await _reply(req, HttpStatus.forbidden, {'error': ApexProtocol.wrongIdentity});
      return;
    }
    final peer = chatPeer(fingerprint, id, address);
    final key = peer.key;

    // Before the token: a block decides even for a device that holds one.
    if (_access.isBlocked(peer)) {
      await _reply(req, HttpStatus.ok, ApexProtocol.refusal);
      return;
    }
    final grant = _access.check(req.headers.value(ApexProtocol.tokenHeader), key);
    if (grant != null) {
      onMessage((id: id, address: address, fingerprint: fingerprint, name: grant.name, text: text));
      await _reply(req, HttpStatus.ok, {'delivered': true});
      return;
    }
    if (_access.isQuiet(key)) {
      await _reply(req, HttpStatus.ok, {'accepted': false, 'reason': ApexProtocol.noAnswer});
      return;
    }
    if (!_question.take()) {
      await _reply(req, HttpStatus.tooManyRequests, {'error': 'busy'});
      return;
    }
    final rawName = body['name'];
    final claimed = cleanLabel(rawName is String ? rawName : null);
    final name = claimed.isEmpty ? address : claimed;
    final bool? accepted;
    try {
      accepted = await _ask(peer, name);
    } finally {
      _question.release();
    }
    if (accepted == null) {
      _access.unanswered(key);
      await _reply(req, HttpStatus.ok, {'accepted': false, 'reason': ApexProtocol.noAnswer});
      return;
    }
    if (!accepted) {
      _access.block(peer);
      onBlocked?.call(peer);
      await _reply(req, HttpStatus.ok, ApexProtocol.refusal);
      return;
    }
    await pins.pin(id, fingerprint);
    final token = _access.admit(peer, name);
    onMessage((id: id, address: address, fingerprint: fingerprint, name: name, text: text));
    await _reply(req, HttpStatus.ok, {'delivered': true, 'token': token});
  }

  /// True or false as the user answered; null when no answer came in time.
  Future<bool?> _ask(ChatPeer peer, String name) async {
    final answer = Completer<bool?>();
    final fingerprint = peer.key.fingerprint;
    final request = ConnectionRequest(
      device: Device(id: peer.id, name: name, type: 'unknown', ip: peer.address, fingerprint: fingerprint),
      fingerprint: fingerprint,
      keyChanged: pins.keyChanged(peer.id, fingerprint),
      fileName: '',
      fileCount: 0,
      kind: RequestKind.chat,
      onResponse: (accepted) {
        if (!answer.isCompleted) {
          answer.complete(accepted);
        }
      },
    );
    onRequest(request);
    try {
      return await answer.future.timeout(decisionTimeout, onTimeout: () => null);
    } finally {
      request.close();
    }
  }

  static const _tooLong = Object();

  /// The decoded body, [_tooLong] past the limit, or null when it is not JSON.
  Future<Object?> _readJson(HttpRequest req) async {
    if (req.contentLength > TransferRules.chatBodyLimit) {
      return _tooLong;
    }
    final bytes = <int>[];
    await for (final chunk in req.timeout(bodyIdleLimit)) {
      bytes.addAll(chunk);
      if (bytes.length > TransferRules.chatBodyLimit) {
        return _tooLong;
      }
    }
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  Future<void> _reply(HttpRequest req, int status, Map<String, Object?> body) async {
    try {
      req.response
        ..statusCode = status
        ..persistentConnection = status < 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    } catch (_) {
      // The sender is gone; nothing to tell.
    }
  }
}
