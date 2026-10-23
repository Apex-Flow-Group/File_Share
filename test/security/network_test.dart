import 'dart:convert';
import 'dart:io';

import 'package:apex_file_share/core/share_folder_http.dart';
import 'package:apex_file_share/services/settings_service.dart';
import 'package:apex_file_share/services/share_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TempShareService extends ShareFolderService {
  _TempShareService(this._path) : super.forTesting();
  final String _path;

  @override
  Future<String> getFolderPath() async => _path;
}

Future<HttpClientResponse> _send(String method, int port, String path,
    [Map<String, String>? query, List<int>? body]) async {
  final client = HttpClient();
  final req = await client.openUrl(method, Uri.http('127.0.0.1:$port', path, query));
  if (body != null) {
    req.contentLength = body.length;
    req.add(body);
  }
  return req.close();
}

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Share folder (Windows, Linux, macOS)', () {
    late Directory dir;
    late HttpServer server;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('apex_share_sec_');
      File('${dir.path}/salary.xlsx').writeAsStringSync('private');
      final share = ShareFolderHttp(
        isEnabled: () => true,
        allowUploads: () => true,
        getLocalName: () => 'Office PC',
        service: _TempShareService(dir.path),
      );
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (!await share.handle(req)) {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });

    test('a device that was never accepted cannot list the folder', () async {
      final res = await _send('GET', server.port, '/share');
      final body = await res.transform(utf8.decoder).join();
      expect(res.statusCode, isNot(HttpStatus.ok),
          reason: 'Any device on the network gets the file list: $body');
    });

    test('a device that was never accepted cannot download a file', () async {
      final res = await _send('GET', server.port, '/share/file', {'name': 'salary.xlsx'});
      await res.drain<void>();
      expect(res.statusCode, isNot(HttpStatus.ok));
    });

    test('a device that was never accepted cannot write into the folder', () async {
      final res = await _send(
          'POST', server.port, '/share/upload', {'name': 'x.txt', 'from': 'x'}, utf8.encode('x'));
      await res.drain<void>();
      expect(dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last),
          isNot(contains('x.txt')));
    });
  });

  test('the share folder and uploads into it are off until the user turns them on', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.loadSettings();
    expect([settings.sharedFolderEnabled, settings.allowShareUploads], [false, false],
        reason: 'lib/services/settings_service.dart:45-46 default both to true: '
            'a fresh install shares its folder with the whole network.');
  });

  group('Doors that open without asking', () {
    test('a file downloaded from another device is never opened by itself', () {
      final src = _read('lib/mobile/screens/share_browser_screen.dart');
      expect(RegExp(r'openFile\(\s*finalPath\s*\)').hasMatch(src), isFalse,
          reason: 'share_browser_screen.dart opens the download at once; on Windows '
              'through cmd, so a served .bat runs as soon as it arrives.');
    });

    test('a name from another device is cleaned before it becomes a download path', () {
      final src = _read('lib/mobile/screens/share_browser_screen.dart');
      expect(RegExp(r"'\$\{tmpDir\.path\}/\$\{file\.name\}'|'\$destDir/\$\{file\.name\}'")
              .hasMatch(src),
          isFalse,
          reason: 'The remote name goes into the path as is: "../" climbs out.');
    });

    test('a nearby phone is not connected without the user agreeing', () {
      final src = _read('lib/core/apex_core.dart');
      final body = RegExp(r'void handleIncomingConnectionInitiated\([^)]*\)\s*async\s*\{([\s\S]*?)\n  \}')
              .firstMatch(src)
              ?.group(1) ??
          '';
      expect(body, isNotEmpty);
      expect(RegExp(r'^\s*await _nearby\.acceptConnection\(').hasMatch(body), isFalse,
          reason: 'Every Nearby connection is accepted at once, and FILE payloads are '
              'saved with no accepted request (nearby_transfer_receive.dart:8-11, 52).');
    });
  });

  group('Internet', () {
    // The only internet addresses the app may know. A new one must be added here on purpose.
    const allowedHosts = {'play.google.com', 'apexflow.now', 'github.com'};

    test('the code contains no internet address outside the allowed list', () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (!p.endsWith('.dart') || p.contains('/l10n/generated/')) {
          continue;
        }
        for (final m in RegExp(r'https?://([A-Za-z0-9.-]+)').allMatches(f.readAsStringSync())) {
          final host = m.group(1)!.replaceFirst(RegExp(r'^www\.'), '');
          if (!allowedHosts.contains(host)) {
            hits.add('$p: ${m.group(0)}');
          }
        }
      }
      expect(hits, isEmpty);
    });

    test('network code lives only in the known files', () {
      const known = {
        'lib/features/send/data/send_http.dart',
        'lib/core/apex_core.dart',
        'lib/services/discovery_service.dart',
        'lib/mobile/screens/share_browser_screen.dart',
      };
      final hits = <String>[];
      final net = RegExp(r'HttpClient\(|RawDatagramSocket\.bind|HttpServer\.bind|'
          r'ServerSocket\.bind|Socket\.connect|WebSocket|package:http/|package:dio/');
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (p.endsWith('.dart') && !known.contains(p) && net.hasMatch(f.readAsStringSync())) {
          hits.add(p);
        }
      }
      expect(hits, isEmpty,
          reason: 'A new place that opens a socket must be reviewed and added here.');
    });

    test('every package in pubspec is really used (no forgotten native code)', () {
      final pubspec = _read('pubspec.yaml');
      final deps = RegExp(r'^dependencies:\s*\n([\s\S]*?)\n\S', multiLine: true)
              .firstMatch(pubspec)
              ?.group(1) ??
          '';
      final names = RegExp(r'^  ([a-z_][a-z0-9_]*):', multiLine: true)
          .allMatches(deps)
          .map((m) => m.group(1)!)
          .where((n) => !{'flutter', 'flutter_localizations', 'cupertino_icons'}.contains(n));
      final code = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final unused = names.where((n) => !code.contains('package:$n/')).toList();
      expect(unused, isEmpty,
          reason: 'An unused package still ships its native code and permissions.');
    });
  });
}
