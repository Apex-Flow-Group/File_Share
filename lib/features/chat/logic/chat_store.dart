import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/device.dart';
import '../../send/data/send_http.dart';

enum ChatStatus { sending, sent, failed }

class ChatMessage {
  ChatMessage._(this.id, this.mine, this.text, this.status);

  final int id;

  /// Written on this device; otherwise received.
  final bool mine;
  final String text;
  ChatStatus status;

  /// Why a message of mine did not arrive.
  ChatOutcome? failure;
}

class ChatThread {
  ChatThread(this.address, this.name);

  /// The device's real address: messages are bound to it, not to the name
  /// or id a device announces about itself.
  final String address;
  String name;
  final messages = <ChatMessage>[];
  int unread = 0;
}

/// Every chat of this run, in memory only: nothing is written to disk, since
/// a message may be a password, and closing the app empties it (owner decision).
class ChatStore extends ChangeNotifier {
  ChatStore({required this.send, this.onBlock, this.onUnblock, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Tell the door, which refuses a blocked device's messages.
  final void Function(String address)? onBlock;
  final void Function(String address)? onUnblock;

  final DateTime Function() _clock;

  /// A device sending without pause announces itself at most this often, so
  /// it cannot keep reopening the TV's chat or stacking notices.
  static const announceEvery = Duration(seconds: 30);
  final _announced = <String, DateTime>{};

  /// Sends one message to [target]; the store keeps the token it returns.
  final Future<({ChatOutcome outcome, String? token})> Function(String text, Device target, String? token)
      send;

  /// Oldest messages go first past this, so a device the user accepted
  /// cannot fill the memory.
  static const maxMessagesPerThread = 500;

  final _threads = <String, ChatThread>{};
  final _incoming = StreamController<ChatThread>.broadcast();

  /// A thread that just received a message the user is not looking at, at
  /// most once per [announceEvery] for each device.
  Stream<ChatThread> get incoming => _incoming.stream;
  final _tokens = <String, String>{};
  var _nextId = 0;

  /// The thread the user is looking at: its messages are not counted unread.
  String? _open;

  ChatThread? thread(String address) => _threads[address];

  int unread(String address) => _threads[address]?.unread ?? 0;

  /// Blocked here, by refusing the question or with the block button; in
  /// memory, like the chats, so closing the app lifts every block.
  final _blocked = <String>{};

  bool isBlocked(String address) => _blocked.contains(address);

  /// A device whose messages this one accepted can be blocked.
  bool canBlock(String address) =>
      !isBlocked(address) && (_threads[address]?.messages.any((m) => !m.mine) ?? false);

  void block(String address) {
    if (!_blocked.add(address)) {
      return;
    }
    _threads[address]?.unread = 0;
    onBlock?.call(address);
    notifyListeners();
  }

  void unblock(String address) {
    if (!_blocked.remove(address)) {
      return;
    }
    onUnblock?.call(address);
    notifyListeners();
  }

  /// The door blocked it, after the user refused its question.
  void blocked(String address) {
    if (_blocked.add(address)) {
      notifyListeners();
    }
  }

  void opened(String address) {
    _open = address;
    final t = _threads[address];
    if (t != null && t.unread > 0) {
      t.unread = 0;
      notifyListeners();
    }
  }

  void closed(String address) {
    if (_open == address) {
      _open = null;
    }
  }

  void receive(String address, String name, String text) {
    if (isBlocked(address)) {
      return;
    }
    final t = _thread(address, name)..name = name;
    _add(t, ChatMessage._(_nextId++, false, text, ChatStatus.sent));
    if (_open != address) {
      t.unread++;
      final last = _announced[address];
      if (last == null || _clock().difference(last) >= announceEvery) {
        _announced[address] = _clock();
        _incoming.add(t);
      }
    }
    notifyListeners();
  }

  Future<void> write(Device target, String text) async {
    if (isBlocked(target.ip)) {
      return;
    }
    final t = _thread(target.ip, target.name);
    final m = ChatMessage._(_nextId++, true, text, ChatStatus.sending);
    _add(t, m);
    notifyListeners();
    await _deliver(target, m);
  }

  /// Only the user resends a failed message: it never goes again by itself.
  Future<void> retry(Device target, ChatMessage m) async {
    if (!m.mine || m.status != ChatStatus.failed) {
      return;
    }
    m
      ..status = ChatStatus.sending
      ..failure = null;
    notifyListeners();
    await _deliver(target, m);
  }

  Future<void> _deliver(Device target, ChatMessage m) async {
    final result = await send(m.text, target, _tokens[target.ip]);
    final token = result.token;
    if (token != null) {
      _tokens[target.ip] = token;
    } else if (result.outcome == ChatOutcome.declined || result.outcome == ChatOutcome.noAnswer) {
      // The receiver asked its user again: the old token is no longer known there.
      _tokens.remove(target.ip);
    }
    if (result.outcome == ChatOutcome.sent) {
      m.status = ChatStatus.sent;
    } else {
      m
        ..status = ChatStatus.failed
        ..failure = result.outcome;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _incoming.close();
    super.dispose();
  }

  ChatThread _thread(String address, String name) =>
      _threads.putIfAbsent(address, () => ChatThread(address, name));

  void _add(ChatThread t, ChatMessage m) {
    t.messages.add(m);
    if (t.messages.length > maxMessagesPerThread) {
      t.messages.removeAt(0);
    }
  }
}
