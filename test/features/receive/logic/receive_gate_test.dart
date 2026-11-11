import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/receive/logic/offer.dart';
import 'package:apex_file_share/features/receive/logic/receive_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Any certificate's fingerprint: these tests are about tokens, not identity.
const _fp = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Offer _offer(List<OfferedFile> files, {String address = '192.168.1.20'}) =>
    Offer(senderAddress: address, senderId: 'phone', senderFingerprint: _fp, senderName: 'Phone', files: files);

void main() {
  group('checkOffer: the batch is refused whole, before anything is written', () {
    const two = [OfferedFile('a.txt', 10), OfferedFile('b.txt', 20)];

    test('a normal batch passes', () {
      expect(checkOffer(_offer(two), freeBytes: 1000), isNull);
    });

    test('an empty batch is refused', () {
      expect(checkOffer(_offer([]), freeBytes: 1000), OfferProblem.noFiles);
    });

    test('more files than the owner limit is refused', () {
      final many = List.generate(
          TransferRules.maxFilesPerBatch + 1, (i) => OfferedFile('f$i', 1));
      expect(checkOffer(_offer(many), freeBytes: null), OfferProblem.tooManyFiles);
      expect(checkOffer(_offer(many.take(TransferRules.maxFilesPerBatch).toList()),
              freeBytes: null),
          isNull);
    });

    test('a negative size is refused', () {
      expect(checkOffer(_offer([const OfferedFile('a', -1)]), freeBytes: null),
          OfferProblem.badSize);
    });

    test('a batch larger than the free space is refused', () {
      expect(checkOffer(_offer(two), freeBytes: 29), OfferProblem.notEnoughSpace);
      expect(checkOffer(_offer(two), freeBytes: 30), isNull);
    });
  });

  group('ReceiveGate: one token per accepted file', () {
    var now = DateTime(2026, 10, 23, 12);
    late ReceiveGate gate;

    setUp(() {
      now = DateTime(2026, 10, 23, 12);
      gate = ReceiveGate(clock: () => now);
    });

    test('each accepted file gets its own token, in order', () {
      final tokens = gate.admit(_offer(const [OfferedFile('a', 1), OfferedFile('b', 2)]));
      expect(tokens, hasLength(2));
      expect(tokens.toSet(), hasLength(2));
      expect(gate.claim(tokens[1], '192.168.1.20', _fp)?.name, 'b');
      expect(gate.claim(tokens[0], '192.168.1.20', _fp)?.name, 'a');
    });

    test('a token works once', () {
      final t = gate.admit(_offer(const [OfferedFile('a', 1)])).single;
      expect(gate.claim(t, '192.168.1.20', _fp), isNotNull);
      expect(gate.claim(t, '192.168.1.20', _fp), isNull);
    });

    test('a token from another address is refused', () {
      final t = gate.admit(_offer(const [OfferedFile('a', 1)])).single;
      expect(gate.claim(t, '192.168.1.99', _fp), isNull);
    });

    test('no token, or an unknown one, is refused', () {
      gate.admit(_offer(const [OfferedFile('a', 1)]));
      expect(gate.claim(null, '192.168.1.20', _fp), isNull);
      expect(gate.claim('', '192.168.1.20', _fp), isNull);
      expect(gate.claim('guess', '192.168.1.20', _fp), isNull);
    });

    test('tokens of a batch left idle expire', () {
      final tokens = gate.admit(_offer(const [OfferedFile('a', 1), OfferedFile('b', 1)]));
      now = now.add(TransferRules.tokenIdleLimit + const Duration(seconds: 1));
      expect(gate.claim(tokens[0], '192.168.1.20', _fp), isNull);
      expect(gate.claim(tokens[1], '192.168.1.20', _fp), isNull);
    });

    test('a batch in use stays open while each file starts in time', () {
      final tokens = gate.admit(_offer(const [OfferedFile('a', 1), OfferedFile('b', 1)]));
      now = now.add(TransferRules.tokenIdleLimit - const Duration(seconds: 1));
      expect(gate.claim(tokens[0], '192.168.1.20', _fp), isNotNull);
      now = now.add(TransferRules.tokenIdleLimit - const Duration(seconds: 1));
      expect(gate.claim(tokens[1], '192.168.1.20', _fp), isNotNull);
    });
  });
}
