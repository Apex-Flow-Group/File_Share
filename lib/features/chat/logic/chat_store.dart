import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/core_models.dart';
import '../../../models/device.dart';
import '../../identity/fingerprint.dart';
import '../../send/data/send_http.dart';
import 'block_list.dart';
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
  ChatThread(this.key, this.id, this.address, this.name);

  /// The device's certificate: messages are bound to it, not to the name,
  /// the id or the address, which any device can announce.
  final ChatKey key;

  /// The id and the real address it last came with, to reach it again.
  String id;
  String address;
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
    BlockList? blocks,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _blocked = blocks ?? BlockList();

  /// Sends files to [target] without adding a line; [sendFiles] adds it.
  /// [onDelivered] counts the files that arrived.
  final Future<SendOutcome> Function(
      List<ChatFile> files, Device target, void Function(int delivered) onDelivered)? sendFilesNow;

  /// Tell the door, which refuses a blocked device's messages.
  final void Function(ChatPeer peer)? onBlock;
  final void Function(ChatPeer peer)? onUnblock;

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

  /// The chat [event]'s file was put in by [receivedFile], if any: none over
  /// Nearby, without a certificate, or from a blocked device.
  ChatKey? chatOf(FileReceivedEvent event) {
    final fingerprint = event.fromFingerprint;
    if (event.fromAddress == null || event.fromId == null || !isFingerprint(fingerprint)) {
      return null;
    }
    final key = ChatKey(fingerprint!);
    return _threads.containsKey(key) ? key : null;
  }

  int unread(ChatKey key) => _threads[key]?.unread ?? 0;

  /// Blocked here, by refusing the question or with the block button; in
  /// memory, like the chats, so closing the app lifts every block. The app
  /// shares it with the doors, so what the card shows is what they decide.
  final BlockList _blocked;

  bool isBlocked(ChatPeer peer) => _blocked.isBlocked(peer);

  /// Owner decision: any device can be blocked, before it ever writes too.
  bool canBlock(ChatPeer peer) => !isBlocked(peer);

  void block(ChatPeer peer) {
    if (isBlocked(peer)) {
      return;
    }
    _blocked.block(peer);
    _threads[peer.key]?.unread = 0;
    onBlock?.call(peer);
    notifyListeners();
  }

  /// Only the user unblocks, and only what turns [peer] away.
  void unblock(ChatPeer peer) {
    if (!isBlocked(peer)) {
      return;
    }
    _blocked.unblock(peer);
    onUnblock?.call(peer);
    notifyListeners();
  }

  /// The door blocked it, after the user refused its question; with a
  /// shared list it is already in, and its card still has to show it.
  void blocked(ChatPeer peer) {
    _blocked.block(peer);
    notifyListeners();
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

  void receive(ChatPeer from, String name, String text) {
    if (isBlocked(from)) {
      return;
    }
    final key = from.key;
    final t = _thread(from, name)..name = name;
    _add(t, ChatMessage._(_nextId++, false, text, ChatStatus.sent));
    if (_open != key) {
      t.unread++;
      final last = _announced[key];
      if (last == null || _clock().difference(last) >= announceEvery) {
        _announced[key] = _clock();
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
    final fingerprint = event.fromFingerprint;
    if (address == null || id == null || !isFingerprint(fingerprint)) {
      return;
    }
    final from = chatPeer(fingerprint!, id, address);
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
      if (_open != from.key) {
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
    if (!target.isMdns || isBlocked(target.chatPeer)) {
      return now(files, target, (_) {});
    }
    final m = ChatMessage._(_nextId++, true, '', ChatStatus.sending, List.of(files));
    _add(_thread(target.chatPeer, target.name), m);
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

  /// How it went, so files sent with it wait for it (owner decision).
  Future<ChatOutcome> write(Device target, String text) async {
    if (isBlocked(target.chatPeer)) {
      return ChatOutcome.declined;
    }
    final t = _thread(target.chatPeer, target.name);
    final m = ChatMessage._(_nextId++, true, text, ChatStatus.sending);
    _add(t, m);
    notifyListeners();
    return _deliver(target, m);
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

  Future<ChatOutcome> _deliver(Device target, ChatMessage m) async {
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
    return result.outcome;
  }

  @override
  void dispose() {
    _incoming.close();
    super.dispose();
  }

  /// [peer]'s chat, which now reaches it at the id and address it came with.
  ChatThread _thread(ChatPeer peer, String name) => _threads.putIfAbsent(
      peer.key, () => ChatThread(peer.key, peer.id, peer.address, name))
    ..id = peer.id
    ..address = peer.address;

  void _add(ChatThread t, ChatMessage m) {
    t.messages.add(m);
    if (t.messages.length > maxMessagesPerThread) {
      t.messages.removeAt(0);
    }
  }
}
