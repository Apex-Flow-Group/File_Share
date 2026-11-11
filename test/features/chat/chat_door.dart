import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/one_question.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/features/chat/data/chat_http.dart';
import 'package:apex_file_share/features/chat/logic/block_list.dart';
import 'package:apex_file_share/features/chat/logic/chat_access.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/identity/pin_store.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';

import '../identity/tls_peer.dart';

/// The chat door and the chats behind one real TLS server on 127.0.0.1,
/// wired as ApexCore wires them. Each peer is a device with its own
/// certificate; [hear] is what discovery heard: which certificate an id came
/// with at an address.
class ChatDoor {
  ChatDoor._(this._server, this.blocks, this.pins) : access = ChatAccess(blocks: blocks);

  final HttpServer _server;

  /// One list for the door and the chats, decided with [pins], as in ApexCore.
  final BlockList blocks;
  final ChatAccess access;
  final PinStore pins;
  late final ChatHttp _door;
  late final ChatStore store = ChatStore(
    send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null),
    onBlock: _door.block,
    onUnblock: _door.unblock,
    blocks: blocks,
  );
  final _heard = <String, String>{};
  final asked = <ConnectionRequest>[];
  final delivered = <IncomingChat>[];

  /// The user's answer to each question; null leaves it unanswered.
  bool? Function(ConnectionRequest) decide = (_) => true;

  int get port => _server.port;

  static Future<ChatDoor> start(TlsPeer me, List<TlsPeer> peers,
      {Duration wait = const Duration(seconds: 5), PinStore? pins}) async {
    final server = await me.bind(peers);
    final kept = pins ?? PinStore.memory();
    final d = ChatDoor._(server, BlockList(kept), kept);
    d._door = ChatHttp(
      expectedFingerprint: (id, address) => d._heard['$id@$address'],
      pins: d.pins,
      onRequest: (r) {
        d.asked.add(r);
        final answer = d.decide(r);
        if (answer != null) {
          r.onResponse(answer);
        }
      },
      onMessage: (m) {
        d.delivered.add(m);
        d.store.receive(chatPeer(m.fingerprint, m.id, m.address), m.name, m.text);
      },
      onBlocked: (peer) => d.store.blocked(peer),
      access: d.access,
      question: OneQuestion(),
      decisionTimeout: wait,
    );
    server.listen((req) async {
      if (!await d._door.handle(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
    return d;
  }

  void hear(TlsPeer peer, String id, {String address = '127.0.0.1'}) =>
      _heard['$id@$address'] = peer.fingerprint;

  Future<void> stop() => _server.close(force: true);

  /// A message from [peer] (its certificate) at [address] (a loopback one),
  /// giving [id].
  Future<({int status, Map json})> post(TlsPeer peer, TlsPeer me, String id, String text,
      {String address = '127.0.0.1', String? token}) async {
    final bytes = utf8.encode(jsonEncode({'id': id, 'name': 'Phone', 'text': text}));
    final socket = await peer.connect(me, port, from: address);
    final crlf = String.fromCharCodes(const [13, 10]);
    final head = StringBuffer()
      ..write('POST ${ApexProtocol.chatPath} HTTP/1.1$crlf')
      ..write('Host: 127.0.0.1:$port$crlf')
      ..write('Content-Type: application/json$crlf')
      ..write('Content-Length: ${bytes.length}$crlf')
      ..write('Connection: close$crlf')
      ..write('${ApexProtocol.versionHeader}: ${ApexProtocol.version}$crlf');
    if (token != null) {
      head.write('${ApexProtocol.tokenHeader}: $token$crlf');
    }
    head.write(crlf);
    socket
      ..add(utf8.encode(head.toString()))
      ..add(bytes);
    await socket.flush();
    final reply = await utf8.decoder.bind(socket).join();
    socket.destroy();
    final status = int.parse(reply.split(' ')[1]);
    final start = reply.indexOf('{');
    final json =
        start < 0 ? <String, Object?>{} : jsonDecode(reply.substring(start, reply.lastIndexOf('}') + 1)) as Map;
    return (status: status, json: json);
  }
}
