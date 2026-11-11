import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/core_models.dart';
import '../../../core/one_question.dart';
import '../../../core/protocol/apex_protocol.dart';
import '../../../core/protocol/transfer_rules.dart';
import '../../../core/text/clean_label.dart';
import '../../../models/device.dart';
import '../logic/chat_access.dart';
import '../logic/chat_text.dart';

typedef IncomingChat = ({String address, String name, String text});

/// The chat door: POST /chat. The first message from an address asks the user;
/// once accepted, the reply carries a token bound to that address, and later
/// messages with it arrive without asking. Nothing is shown before the user
/// agrees, so a stranger cannot put text on the screen.
class ChatHttp {
  ChatHttp({
    required this.onRequest,
    required this.onMessage,
    ChatAccess? access,
    OneQuestion? question,
    this.decisionTimeout = TransferRules.decisionTimeout,
    this.bodyIdleLimit = TransferRules.bodyIdleLimit,
  })  : _access = access ?? ChatAccess(),
        _question = question ?? OneQuestion();

  final void Function(ConnectionRequest) onRequest;
  final void Function(IncomingChat) onMessage;
  final Duration decisionTimeout;
  final Duration bodyIdleLimit;
  final ChatAccess _access;
  final OneQuestion _question;

  /// False when [req] is not for this door.
  Future<bool> handle(HttpRequest req) async {
    if (req.uri.path != ApexProtocol.chatPath) {
      return false;
    }
    if (!ApexProtocol.accepts(req.headers.value(ApexProtocol.versionHeader))) {
      await _reply(req, HttpStatus.upgradeRequired,
          {'error': ApexProtocol.updateRequired, 'version': ApexProtocol.version});
      return true;
    }
    if (req.method != 'POST') {
      await _reply(req, HttpStatus.methodNotAllowed, {'error': 'method'});
      return true;
    }
    await _message(req);
    return true;
  }

  Future<void> _message(HttpRequest req) async {
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
    if (address == null || body is! Map || text == null) {
      await _reply(req, HttpStatus.badRequest, {'error': 'bad_message'});
      return;
    }

    final grant = _access.check(req.headers.value(ApexProtocol.tokenHeader), address);
    if (grant != null) {
      onMessage((address: address, name: grant.name, text: text));
      await _reply(req, HttpStatus.ok, {'delivered': true});
      return;
    }
    if (_access.isDeclined(address)) {
      await _reply(req, HttpStatus.ok, {'accepted': false});
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
      accepted = await _ask(address, name);
    } finally {
      _question.release();
    }
    if (accepted == null) {
      await _reply(req, HttpStatus.ok, {'accepted': false, 'reason': ApexProtocol.noAnswer});
      return;
    }
    if (!accepted) {
      _access.decline(address);
      await _reply(req, HttpStatus.ok, {'accepted': false});
      return;
    }
    final token = _access.admit(address, name);
    onMessage((address: address, name: name, text: text));
    await _reply(req, HttpStatus.ok, {'delivered': true, 'token': token});
  }

  /// True or false as the user answered; null when no answer came in time.
  Future<bool?> _ask(String address, String name) async {
    final answer = Completer<bool?>();
    final request = ConnectionRequest(
      device: Device(id: 'http:$address', name: name, type: 'unknown', ip: address),
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
