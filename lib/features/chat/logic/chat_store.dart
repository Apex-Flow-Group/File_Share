import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/core_models.dart';
import '../../../models/device.dart';
import '../../send/data/send_http.dart';
import 'chat_key.dart';

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

  /// Files of mine that arrived, in order: a retry sends only the rest.
  int delivered = 0;

  /// The received batch this line shows.
  int? batchId;

  List<ChatFile> get undelivered => files.sublist(delivered);
}

class ChatThread {
  ChatThread(this.key, this.name);

  /// The device's id at its real address: messages are bound to both, not
  /// to the name, and not to an address another device may get next.
  final ChatKey key;
  String get id => key.id;
  String get address => key.address;
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
  /// [onDelivered] counts the files that arrived.
  final Future<SendOutcome> Function(
      List<ChatFile> files, Device target, void Function(int delivered) onDelivered)? sendFilesNow;

  /// Tell the door, which refuses a blocked device's messages.
  final void Function(ChatKey key)? onBlock;
  final void Function(ChatKey key)? onUnblock;

  final DateTime Function() _clock;

  /// A device sending without pause announces itself at most this often, so
  /// it cannot keep reopening the TV's chat or stacking notices.
  static const announceEvery = Duration(seconds: 30);
  final _announced = <ChatKey, DateTime>{};

  /// Sends one message to [target]; the store keeps the token it returns.
  final Future<({ChatOutcome outcome, String? token})> Function(String text, Device target, String? token)
      send;

  /// Oldest messages go first past this, so a device the user accepted
  /// cannot fill the memory.
  static const maxMessagesPerThread = 500;

  final _threads = <ChatKey, ChatThread>{};
  final _incoming = StreamController<ChatThread>.broadcast();

  /// A thread that just received a message the user is not looking at, at
  /// most once per [announceEvery] for each device.
  Stream<ChatThread> get incoming => _incoming.stream;
  final _tokens = <ChatKey, String>{};
  var _nextId = 0;

  /// The thread the user is looking at: its messages are not counted unread.
  ChatKey? _open;

  ChatThread? thread(ChatKey key) => _threads[key];

  int unread(ChatKey key) => _threads[key]?.unread ?? 0;

  /// Blocked here, by refusing the question or with the block button; in
  /// memory, like the chats, so closing the app lifts every block.
  final _blocked = <ChatKey>{};

  bool isBlocked(ChatKey key) => _blocked.contains(key);

  /// Owner decision: any device can be blocked, before it ever writes too.
  bool canBlock(ChatKey key) => !isBlocked(key);

  void block(ChatKey key) {
    if (!_blocked.add(key)) {
      return;
    }
    _threads[key]?.unread = 0;
    onBlock?.call(key);
    notifyListeners();
  }

  void unblock(ChatKey key) {
    if (!_blocked.remove(key)) {
      return;
    }
    onUnblock?.call(key);
    notifyListeners();
  }

  /// The door blocked it, after the user refused its question.
  void blocked(ChatKey key) {
    if (_blocked.add(key)) {
      notifyListeners();
    }
  }

  void opened(ChatKey key) {
    _open = key;
    final t = _threads[key];
    if (t != null && t.unread > 0) {
      t.unread = 0;
      notifyListeners();
    }
  }

  void closed(ChatKey key) {
    if (_open == key) {
      _open = null;
    }
  }

  void receive(ChatKey from, String name, String text) {
    if (isBlocked(from)) {
      return;
    }
    final t = _thread(from, name)..name = name;
    _add(t, ChatMessage._(_nextId++, false, text, ChatStatus.sent));
    if (_open != from) {
      t.unread++;
      final last = _announced[from];
      if (last == null || _clock().difference(last) >= announceEvery) {
        _announced[from] = _clock();
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
    final id = event.fromId;
    if (address == null || id == null) {
      return;
    }
    final from = chatKey(id, address);
    if (isBlocked(from)) {
      return;
    }
    final t = _thread(from, event.fromDevice);
    final file = ChatFile(event.fileName, event.fileSize, event.filePath);
    final batch = event.batchId;
    final line = batch == null
        ? null
        : t.messages.where((m) => !m.mine && m.isFiles && m.batchId == batch).lastOrNull;
    if (line != null) {
      line.files.add(file);
    } else {
      _add(t, ChatMessage._(_nextId++, false, '', ChatStatus.sent, [file])..batchId = batch);
      if (_open != from) {
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
    if (!target.isMdns || isBlocked(target.chatKey)) {
      return now(files, target, (_) {});
    }
    final m = ChatMessage._(_nextId++, true, '', ChatStatus.sending, List.of(files));
    _add(_thread(target.chatKey, target.name), m);
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
    final before = m.delivered;
    SendOutcome outcome;
    try {
      outcome = await sendFilesNow!(m.undelivered, target, (n) => m.delivered = before + n);
    } catch (_) {
      // A line never stays "sending": the send threw (a disk removed mid-read).
      outcome = SendOutcome.failed;
    }
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
    if (isBlocked(target.chatKey)) {
      return;
    }
    final t = _thread(target.chatKey, target.name);
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
    final key = target.chatKey;
    final result = await send(m.text, target, _tokens[key]);
    final token = result.token;
    if (token != null) {
      _tokens[key] = token;
    } else if (result.outcome == ChatOutcome.declined || result.outcome == ChatOutcome.noAnswer) {
      // The receiver asked its user again: the old token is no longer known there.
      _tokens.remove(key);
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

  ChatThread _thread(ChatKey key, String name) =>
      _threads.putIfAbsent(key, () => ChatThread(key, name));

  void _add(ChatThread t, ChatMessage m) {
    t.messages.add(m);
    if (t.messages.length > maxMessagesPerThread) {
      t.messages.removeAt(0);
    }
  }
}
