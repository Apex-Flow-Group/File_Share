import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/core_models.dart';
import '../../../models/device.dart';
import '../../send/data/send_http.dart';

enum ChatStatus { sending, sent, failed }

class ChatFile {
  const ChatFile(this.name, this.size, this.path);
  final String name;
  final int size;

  /// Where it is on this device: saved here, or sent from here.
  final String path;
}

class ChatMessage {
  ChatMessage._(this.id, this.mine, this.text, this.status, [List<ChatFile>? files])
      : files = files ?? [];

  final int id;

  /// Written on this device; otherwise received.
  final bool mine;
  final String text;
  ChatStatus status;

  /// Why a message of mine did not arrive.
  ChatOutcome? failure;

  /// A line of files instead of text: one line per batch.
  final List<ChatFile> files;
  bool get isFiles => files.isNotEmpty;

  /// Why files of mine did not arrive.
  SendOutcome? filesFailure;
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
  ChatStore({
    required this.send,
    this.sendFilesNow,
    this.onBlock,
    this.onUnblock,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Sends files to [target] without adding a line; [sendFiles] adds it.
  final Future<SendOutcome> Function(List<ChatFile> files, Device target)? sendFilesNow;

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

  /// A device whose chat this one accepted (a text from it arrived) can be
  /// blocked; files come through their own question, per batch.
  bool canBlock(String address) =>
      !isBlocked(address) &&
      (_threads[address]?.messages.any((m) => !m.mine && !m.isFiles) ?? false);

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

  /// A file saved from [event]'s sender: a batch is one line, filled as its
  /// files arrive. Counted unread once, and not announced: the received
  /// sheet already says it arrived.
  void receivedFile(FileReceivedEvent event) {
    final address = event.fromAddress;
    if (address == null || isBlocked(address)) {
      return;
    }
    final t = _thread(address, event.fromDevice);
    final file = ChatFile(event.fileName, event.fileSize, event.filePath);
    final last = t.messages.isEmpty ? null : t.messages.last;
    if (event.batchIndex > 1 && last != null && !last.mine && last.isFiles) {
      last.files.add(file);
    } else {
      _add(t, ChatMessage._(_nextId++, false, '', ChatStatus.sent, [file]));
      if (_open != address) {
        t.unread++;
      }
    }
    notifyListeners();
  }

  /// Sends [files] to [target] with a line in its chat that shows how it
  /// ended. A Nearby phone or a blocked device gets no line.
  Future<SendOutcome> sendFiles(Device target, List<ChatFile> files) async {
    final now = sendFilesNow;
    if (now == null) {
      return SendOutcome.failed;
    }
    if (!target.isMdns || isBlocked(target.ip)) {
      return now(files, target);
    }
    final m = ChatMessage._(_nextId++, true, '', ChatStatus.sending, List.of(files));
    _add(_thread(target.ip, target.name), m);
    notifyListeners();
    await _deliverFiles(target, m);
    return m.filesFailure ?? SendOutcome.sent;
  }

  /// Retry helps only where the same files can go again the same way.
  static bool retryHelps(SendOutcome failure) => switch (failure) {
        SendOutcome.failed || SendOutcome.noAnswer || SendOutcome.busy => true,
        _ => false,
      };

  /// Only the user resends failed files, the same line, never by itself.
  Future<void> retryFiles(Device target, ChatMessage m) async {
    final failure = m.filesFailure;
    if (!m.mine || !m.isFiles || failure == null || !retryHelps(failure)) {
      return;
    }
    m
      ..status = ChatStatus.sending
      ..filesFailure = null;
    notifyListeners();
    await _deliverFiles(target, m);
  }

  Future<void> _deliverFiles(Device target, ChatMessage m) async {
    final outcome = await sendFilesNow!(m.files, target);
    if (outcome == SendOutcome.sent) {
      m.status = ChatStatus.sent;
    } else {
      m
        ..status = ChatStatus.failed
        ..filesFailure = outcome;
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
    if (!m.mine || m.isFiles || m.status != ChatStatus.failed) {
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
