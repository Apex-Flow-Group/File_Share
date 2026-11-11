import 'package:apex_file_share/features/chat/logic/chat_access.dart';
import 'package:apex_file_share/features/chat/logic/chat_key.dart';
import 'package:apex_file_share/features/chat/logic/chat_store.dart';
import 'package:apex_file_share/features/chat/ui/device_chat_view.dart';
import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = Device(id: 'p', name: 'Office PC', type: 'desktop', ip: '10.0.0.7', port: 4000);

void main() {
  group('the door', () {
    test('a blocked device loses its token and is not asked about', () {
      final access = ChatAccess();
      final token = access.admit(_pc.chatKey, 'PC');
      access.block(_pc.chatKey);
      expect(access.check(token, _pc.chatKey), isNull);
      expect(access.isBlocked(_pc.chatKey), isTrue);
    });

    test('unblocking does not let it in: its next message asks again', () {
      final access = ChatAccess();
      final token = access.admit(_pc.chatKey, 'PC');
      access
        ..block(_pc.chatKey)
        ..unblock(_pc.chatKey);
      expect(access.isBlocked(_pc.chatKey), isFalse);
      expect(access.check(token, _pc.chatKey), isNull, reason: 'the old token stays dead');
    });

    test('blocking one address leaves the others alone', () {
      final access = ChatAccess();
      final other = access.admit(chatKey('ph', '10.0.0.8'), 'Phone');
      access.block(_pc.chatKey);
      expect(access.check(other, chatKey('ph', '10.0.0.8')), isNotNull);
    });
  });

  group('the store', () {
    late List<ChatKey> blockedAtDoor;
    late List<ChatKey> unblockedAtDoor;
    late List<String> sent;
    late ChatStore store;

    setUp(() {
      blockedAtDoor = [];
      unblockedAtDoor = [];
      sent = [];
      store = ChatStore(
        send: (text, target, token) async {
          sent.add(text);
          return (outcome: ChatOutcome.sent, token: null);
        },
        onBlock: blockedAtDoor.add,
        onUnblock: unblockedAtDoor.add,
      );
    });

    test('any device can be blocked, before it ever writes, but not twice', () {
      expect(store.canBlock(_pc.chatKey), isTrue);
      store.block(_pc.chatKey);
      expect(store.canBlock(_pc.chatKey), isFalse);
    });

    test('blocking tells the door, and nothing more arrives or goes', () async {
      store.receive(_pc.chatKey, 'PC', 'one');
      store.block(_pc.chatKey);
      expect(blockedAtDoor, [_pc.chatKey]);
      store.receive(_pc.chatKey, 'PC', 'two');
      await store.write(_pc, 'mine');
      expect(store.thread(_pc.chatKey)!.messages.map((m) => m.text), ['one']);
      expect(sent, isEmpty);
      expect(store.unread(_pc.chatKey), 0);
    });

    test('unblocking tells the door and lets the chat go on', () async {
      store.receive(_pc.chatKey, 'PC', 'one');
      store.block(_pc.chatKey);
      store.unblock(_pc.chatKey);
      expect(unblockedAtDoor, [_pc.chatKey]);
      expect(store.isBlocked(_pc.chatKey), isFalse);
      await store.write(_pc, 'back');
      expect(sent, ['back']);
    });

    test('a refusal at the question shows as blocked, without calling the door back', () {
      var notified = 0;
      store.addListener(() => notified++);
      store.blocked(_pc.chatKey);
      expect(store.isBlocked(_pc.chatKey), isTrue);
      expect(blockedAtDoor, isEmpty);
      expect(notified, 1);
    });
  });

  Future<AppLocalizations> show(WidgetTester tester, ChatStore store, {required bool canWrite}) async {
    const locale = Locale('ar');
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: DeviceChatView(store: store, device: _pc, canWrite: canWrite)),
    ));
    return AppLocalizations.delegate.load(locale);
  }

  ChatStore blockedStore() {
    final store = ChatStore(send: (t, d, k) async => (outcome: ChatOutcome.sent, token: null));
    store.receive(_pc.chatKey, 'PC', 'hello');
    store.block(_pc.chatKey);
    return store;
  }

  testWidgets('a blocked chat says so, has no writing line, and can be unblocked', (tester) async {
    final store = blockedStore();
    final l10n = await show(tester, store, canWrite: true);
    expect(find.text(l10n.chatBlocked), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text(l10n.chatUnblock));
    await tester.pump();
    expect(store.isBlocked(_pc.chatKey), isFalse);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('on the TV the chat says it is blocked; unblocking is on the dialog buttons', (tester) async {
    final store = blockedStore();
    final l10n = await show(tester, store, canWrite: false);
    expect(find.text(l10n.chatBlocked), findsOneWidget);
    expect(find.text(l10n.chatUnblock), findsNothing);
  });
}
