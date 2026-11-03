import 'package:apex_file_share/core/core_models.dart';
import 'package:apex_file_share/core/protocol/apex_protocol.dart';
import 'package:apex_file_share/core/protocol/nearby_messages.dart';
import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/receive/logic/nearby_door.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Nearby door with a scripted user and a record of what it sent back.
class _Harness {
  _Harness({bool? answer, Duration announceWait = const Duration(milliseconds: 200)})
      : _answer = answer {
    door = NearbyDoor(
      onConnectionRequest: (r) {
        asked.add(r);
        final a = _answer;
        if (a != null) {
          r.onResponse(a);
        }
      },
      send: (endpoint, msg) async => sent.add((endpoint, msg)),
      decisionTimeout: const Duration(milliseconds: 100),
      announceWait: announceWait,
    );
  }

  final bool? _answer;
  late final NearbyDoor door;
  final asked = <ConnectionRequest>[];
  final sent = <(String, Map<String, Object?>)>[];

  Map<String, Object?> get lastAnswer => sent.last.$2;

  List<String> get tokens => (lastAnswer['tokens']! as List).cast<String>();
}

Map<String, Object?> _offer(List<(String, int)> files, {Object? version = ApexProtocol.version}) => {
      'type': NearbyMessage.offer,
      if (version != null) 'version': version,
      'name': 'Phone',
      'files': [
        for (final f in files) {'name': f.$1, 'size': f.$2}
      ],
    };

Map<String, Object?> _announce(String token, int payloadId) =>
    {'type': NearbyMessage.file, 'token': token, 'payload_id': payloadId};

void main() {
  group('connection', () {
    test('a nearby phone is connected only after the user agrees', () async {
      final yes = _Harness(answer: true);
      expect(await yes.door.mayConnect('ep1', 'Phone'), isTrue);
      expect(yes.asked, hasLength(1));
      expect(yes.asked.single.asksToConnect, isTrue);

      final no = _Harness(answer: false);
      expect(await no.door.mayConnect('ep1', 'Phone'), isFalse);
    });

    test('no answer within the decision time refuses the connection', () async {
      final h = _Harness();
      expect(await h.door.mayConnect('ep1', 'Phone'), isFalse);
    });

    test('a second question while one waits is refused without asking', () async {
      final h = _Harness();
      final first = h.door.mayConnect('ep1', 'Phone');
      expect(await h.door.mayConnect('ep2', 'Other'), isFalse);
      expect(h.asked, hasLength(1), reason: 'Questions stacked over each other: '
          'a new one appears under the finger that is pressing Accept.');
      await first;
    });

    test('the shown name is cleaned of direction marks and new lines', () async {
      final h = _Harness(answer: false);
      await h.door.mayConnect('ep1', 'Office${String.fromCharCode(0x202E)} PC\nfake');
      expect(h.asked.single.device.name, 'Office PC fake');
    });
  });

  group('files', () {
    test('a file with no accepted offer is not expected and not saved', () async {
      final h = _Harness(answer: true);
      expect(h.door.expectsFile('ep1'), isFalse);
      expect(await h.door.takeFile('ep1', 7), isNull);
    });

    test('an offer with no version or another version is refused unasked', () async {
      for (final version in [null, ApexProtocol.version - 1, '${ApexProtocol.version}']) {
        final h = _Harness(answer: true);
        await h.door.onMessage('ep1', _offer([('a.txt', 3)], version: version));
        expect(h.asked, isEmpty, reason: 'version $version');
        expect(h.lastAnswer['accepted'], isFalse);
        expect(h.lastAnswer['error'], ApexProtocol.updateRequired);
        expect(h.door.expectsFile('ep1'), isFalse);
      }
    });

    test('a refused offer lets no file in', () async {
      final h = _Harness(answer: false);
      await h.door.onMessage('ep1', _offer([('a.txt', 3)]));
      expect(h.lastAnswer, {'type': NearbyMessage.answer, 'accepted': false});
      expect(h.door.expectsFile('ep1'), isFalse);
    });

    test('a batch above the owner limit is refused before the user is asked', () async {
      final h = _Harness(answer: true);
      await h.door.onMessage(
          'ep1', _offer([for (var i = 0; i <= TransferRules.maxFilesPerBatch; i++) ('f$i', 1)]));
      expect(h.asked, isEmpty);
      expect(h.lastAnswer['accepted'], isFalse);
    });

    test('an accepted file keeps the accepted name and size, once', () async {
      final h = _Harness(answer: true);
      await h.door.onMessage('ep1', _offer([('../../shared_prefs/x.xml', 3)]));
      expect(h.asked.single.fileNames.single, isNot(contains('/')));
      final token = h.tokens.single;
      expect(h.door.expectsFile('ep1'), isTrue);

      await h.door.onMessage('ep1', _announce(token, 7));
      final file = await h.door.takeFile('ep1', 7);
      expect(file, isNotNull);
      expect(file!.name, h.asked.single.fileNames.single);
      expect(file.name, isNot(contains('/')));
      expect(file.name.startsWith('.'), isFalse);
      expect(file.size, 3);

      await h.door.onMessage('ep1', _announce(token, 8));
      expect(await h.door.takeFile('ep1', 8), isNull, reason: 'a token is used once');
      expect(h.door.expectsFile('ep1'), isFalse);
    });

    test('a token is valid only on the connection it was given to', () async {
      final h = _Harness(answer: true);
      await h.door.onMessage('ep1', _offer([('a.txt', 3)]));
      await h.door.onMessage('ep2', _announce(h.tokens.single, 7));
      expect(await h.door.takeFile('ep2', 7), isNull);
    });

    test('a file whose name arrives after its bytes is still matched', () async {
      final h = _Harness(answer: true, announceWait: const Duration(seconds: 2));
      await h.door.onMessage('ep1', _offer([('a.txt', 3)]));
      final token = h.tokens.single;
      final taken = h.door.takeFile('ep1', 7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await h.door.onMessage('ep1', _announce(token, 7));
      expect((await taken)?.name, 'a.txt');
    });

    test('a file never announced is dropped after the wait', () async {
      final h = _Harness(answer: true);
      await h.door.onMessage('ep1', _offer([('a.txt', 3)]));
      expect(await h.door.takeFile('ep1', 7), isNull);
    });

    test('a lost connection lets nothing more in', () async {
      final h = _Harness(answer: true);
      await h.door.onMessage('ep1', _offer([('a.txt', 3), ('b.txt', 4)]));
      final tokens = h.tokens;
      h.door.forget('ep1');
      expect(h.door.expectsFile('ep1'), isFalse);
      await h.door.onMessage('ep1', _announce(tokens.first, 7));
      expect(await h.door.takeFile('ep1', 7), isNull);
    });

    test('a message that is not an offer or a file note is ignored', () async {
      final h = _Harness(answer: true);
      await h.door.onMessage('ep1', {'type': 'request', 'name': 'a.txt', 'size': 3});
      await h.door.onMessage('ep1', 'not a map');
      expect(h.asked, isEmpty);
      expect(h.door.expectsFile('ep1'), isFalse);
    });
  });
}
