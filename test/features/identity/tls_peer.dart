import 'dart:io';

import 'package:apex_file_share/features/identity/device_identity.dart';
import 'package:apex_file_share/features/identity/fingerprint.dart';
import 'package:apex_file_share/features/identity/peer_trust.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/models/device.dart';

/// A device identity made in a temp folder (deleted once it is read), with
/// the TLS pieces a test needs: a server that asks for client certificates,
/// and clients that show this certificate and accept only their server.
class TlsPeer {
  TlsPeer._(this.identity);

  final DeviceIdentity identity;

  static Future<TlsPeer> create() async {
    final folder = await Directory.systemTemp.createTemp('apex_identity_');
    try {
      return TlsPeer._(await DeviceIdentity.loadOrCreate(folder));
    } finally {
      await folder.delete(recursive: true);
    }
  }

  String get fingerprint => identity.fingerprint;

  /// This peer as discovery would list it, serving on [port].
  Device device(int port, {String id = 'test-pc', String ip = '127.0.0.1'}) => Device(
      id: id,
      name: 'Test PC',
      type: 'desktop',
      ip: ip,
      port: port,
      fingerprint: fingerprint,
      certificate: identity.certificate);

  /// A TLS server with this identity that lets [clients] finish the handshake,
  /// as ApexCore does for every device discovery heard.
  Future<HttpServer> bind(Iterable<TlsPeer> clients) {
    final context = identity.serverContext();
    final trust = PeerTrust(context);
    for (final c in clients) {
      trust.trust(c.identity.certificate);
    }
    return HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context,
        requestClientCertificate: true);
  }

  /// Shows this certificate and talks only to [server].
  HttpClient client(TlsPeer server) => pinnedClient(identity.clientContext(), server.device(1));

  /// A raw TLS connection from [from] (a loopback address) to [server] on [port].
  Future<SecureSocket> connect(TlsPeer server, int port, {String from = '127.0.0.1'}) async {
    final raw = await Socket.connect(InternetAddress.loopbackIPv4, port,
        sourceAddress: InternetAddress(from));
    return SecureSocket.secure(raw,
        context: identity.clientContext(),
        onBadCertificate: (cert) => fingerprintOf(cert.der) == server.fingerprint);
  }
}

/// A client with no certificate of its own that accepts any server.
HttpClient clientWithoutCertificate() =>
    HttpClient(context: SecurityContext(withTrustedRoots: false))..badCertificateCallback = (_, __, ___) => true;

/// For tests about something else than identity: the device under test, and
/// the one device that talks to it, made once per test file.
final Future<TlsPeer> receiverPeer = TlsPeer.create();
final Future<TlsPeer> senderPeer = TlsPeer.create();

/// A TLS server as the device under test, which [senderPeer] can reach.
Future<HttpServer> bindReceiver() async => (await receiverPeer).bind([await senderPeer]);

/// A client as [senderPeer], talking to [receiverPeer].
Future<HttpClient> senderClient() async => (await senderPeer).client(await receiverPeer);

/// A raw TLS connection as [senderPeer] from [from].
Future<SecureSocket> senderSocket(int port, {String from = '127.0.0.1'}) async =>
    (await senderPeer).connect(await receiverPeer, port, from: from);

/// What discovery heard in such tests: whatever id and address a request
/// gives, it is the sender.
Future<String? Function(String, String)> heardSender() async {
  final fp = (await senderPeer).fingerprint;
  return (_, __) => fp;
}

/// The two peers above, for synchronous code once setUpAll(loadPeers) ran.
late TlsPeer testReceiver;
late TlsPeer testSender;

Future<void> loadPeers() async {
  testReceiver = await receiverPeer;
  testSender = await senderPeer;
}

/// SendHttp.getContext for a sender that is [testSender].
SecurityContext? senderContext() => testSender.identity.clientContext();
