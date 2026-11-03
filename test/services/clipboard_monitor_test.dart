@TestOn('linux || windows')
library;

import 'dart:io';

import 'package:apex_file_share/services/clipboard_monitor_service.dart';
import 'package:apex_file_share/services/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.apex.core/clipboard');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> nativeCalls;
  late Directory root;

  setUp(() async {
    nativeCalls = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      nativeCalls.add(call.method);
      return null;
    });
    root = await Directory.systemTemp.createTemp('apex_clip_test_');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_channel, null);
    await root.delete(recursive: true);
  });

  /// What the Windows and Linux runners send when the user copies [text].
  Future<void> copy(String text) => messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(
          MethodCall('onClipboardChanged', {'type': 'text', 'text': text})),
      (_) {});

  List<FileSystemEntity> filesUnder(Directory d) => d.listSync(recursive: true);

  test('watching the clipboard is off until the user turns it on', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.loadSettings();
    expect(settings.clipboardMonitorEnabled, isFalse);

    await settings.setClipboardMonitorEnabled(true);
    final reloaded = SettingsService();
    await reloaded.loadSettings();
    expect(reloaded.clipboardMonitorEnabled, isTrue);
  });

  test('the system clipboard is not watched before the user turns it on', () async {
    final service = ClipboardMonitorService.forTesting();
    service.initialize();
    expect(nativeCalls, isEmpty, reason: 'The runners must not listen on their own.');

    await service.setEnabled(true);
    await service.setEnabled(true);
    await service.setEnabled(false);
    expect(nativeCalls, ['start', 'stop']);
  });

  test('a copy while turned off is ignored', () async {
    final service = ClipboardMonitorService.forTesting();
    service.initialize();
    final items = <ClipboardItem?>[];
    service.stream.listen(items.add);
    await copy('password123');
    await Future<void>.delayed(Duration.zero);
    expect(items.whereType<ClipboardItem>(), isEmpty);
  });

  test('copied text stays in memory and is not written anywhere', () async {
    final service = ClipboardMonitorService.forTesting();
    service.initialize();
    await service.setEnabled(true);
    final items = <ClipboardItem?>[];
    service.stream.listen(items.add);

    await copy('password123');
    await Future<void>.delayed(Duration.zero);

    final item = items.single!;
    expect(item.type, ClipboardItemType.text);
    expect(item.text, 'password123');
    expect(item.paths, isEmpty);
    expect(filesUnder(root), isEmpty);
  });

  test('text becomes a file only while it is sent, then the file is gone', () async {
    final service = ClipboardMonitorService.forTesting();
    const item = ClipboardItem(paths: [], type: ClipboardItemType.text, text: 'hello');
    late List<String> sent;
    late String content;

    await service.withSendableFiles(item, (paths) async {
      sent = paths;
      content = File(paths.single).readAsStringSync();
      return true;
    }, tempRoot: root);

    expect(content, 'hello');
    expect(sent.single.endsWith('.txt'), isTrue);
    expect(filesUnder(root), isEmpty);
  });

  test('the file is gone even when the send fails', () async {
    final service = ClipboardMonitorService.forTesting();
    const item = ClipboardItem(paths: [], type: ClipboardItemType.text, text: 'hello');
    await expectLater(
        service.withSendableFiles<bool>(item, (_) async => throw const SocketException('down'),
            tempRoot: root),
        throwsA(isA<SocketException>()));
    expect(filesUnder(root), isEmpty);
  });

  test('the file is readable by its owner only (Linux)', () async {
    final service = ClipboardMonitorService.forTesting();
    const item = ClipboardItem(paths: [], type: ClipboardItemType.text, text: 'hello');
    await service.withSendableFiles(item, (paths) async {
      final folder = File(paths.single).parent.statSync();
      expect(folder.mode & 0x3F, 0, reason: 'group and others: no access');
      return true;
    }, tempRoot: root);
  }, testOn: 'linux');
}
