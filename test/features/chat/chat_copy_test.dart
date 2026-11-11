@TestOn('linux || windows')
library;

import 'dart:io';

import 'package:apex_file_share/services/clipboard_monitor_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.apex.core/clipboard');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(_channel, (_) async => null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// What the Windows and Linux runners send when the clipboard holds [text].
  Future<void> changed(String text) => messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(
          MethodCall('onClipboardChanged', {'type': 'text', 'text': text})),
      (_) {});

  test('a chat message the user copies is not offered for sending back', () async {
    final service = ClipboardMonitorService.forTesting()..initialize();
    await service.setEnabled(true);
    final items = <ClipboardItem?>[];
    service.stream.listen(items.add);

    await service.copyText('from the phone');
    await changed('from the phone');
    await Future<void>.delayed(Duration.zero);
    expect(items, isEmpty);

    // The user's own copy afterwards, even of the same text, still counts.
    await changed('from the phone');
    await Future<void>.delayed(Duration.zero);
    expect(items.single?.text, 'from the phone');
  });

  test('every door asks through one shared question, so two never stack', () {
    final core = File('lib/core/apex_core.dart').readAsStringSync();
    expect(RegExp(r'question: _question').allMatches(core), hasLength(4),
        reason: 'files, chat, the shared folder and Nearby');
  });
}
