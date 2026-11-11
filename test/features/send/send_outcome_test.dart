import 'dart:io';

import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/features/send/ui/send_outcome_message.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../receive/data/receive_test_server.dart';

/// The user must see why a send did not go through: "send failed" for an
/// old app, a refusal or a busy receiver tells them nothing to do.
void main() {
  test('a receiver already asking its user about another offer is reported as busy', () async {
    final s = await ReceiveTestServer.start(decide: (_) => null);
    addTearDown(s.stop);
    final root = await Directory.systemTemp.createTemp('apex_send_busy_');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/a.txt')..writeAsStringSync('x');
    final files = [(path: file.path, name: 'a.txt', size: 1)];
    final target = Device(id: 't', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: s.port);

    final first = SendHttp(getLocalName: () => 'Phone A', getLocalId: () => 'test-id').sendFiles(files, target);
    while (s.shown.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final second = await SendHttp(getLocalName: () => 'Phone B', getLocalId: () => 'test-id').sendFiles(files, target);

    expect(second, SendOutcome.busy);
    s.shown.single.onResponse(false);
    expect(await first, SendOutcome.declined);
  });

  test('a receiver whose user never answers is reported as "no answer", not as a refusal', () async {
    final s = await ReceiveTestServer.start(
        decide: (_) => null, decisionTimeout: const Duration(milliseconds: 200));
    addTearDown(s.stop);
    final root = await Directory.systemTemp.createTemp('apex_send_no_answer_');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/a.txt')..writeAsStringSync('x');
    final target = Device(id: 't', name: 'Receiver', type: 'desktop', ip: '127.0.0.1', port: s.port);

    final outcome = await SendHttp(getLocalName: () => 'Phone', getLocalId: () => 'test-id')
        .sendFiles([(path: file.path, name: 'a.txt', size: 1)], target);

    expect(outcome, SendOutcome.noAnswer);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('each reason has its own message (${locale.languageCode})', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      String message(SendOutcome o) => sendOutcomeMessage(l10n, o, sent: 'SENT', failed: 'FAILED');

      expect(message(SendOutcome.sent), 'SENT');
      expect(message(SendOutcome.failed), 'FAILED');
      final reasons = [
        SendOutcome.updateRequired,
        SendOutcome.declined,
        SendOutcome.noAnswer,
        SendOutcome.busy,
        SendOutcome.tooManyFiles,
        SendOutcome.noSpace,
        SendOutcome.cancelled,
      ].map(message).toList();
      expect(reasons.toSet(), hasLength(reasons.length));
      expect(reasons, everyElement(isNot(anyOf('SENT', 'FAILED', isEmpty))));
      expect(SendOutcome.values, hasLength(9), reason: 'A new outcome needs its message here.');
    });
  }
}
