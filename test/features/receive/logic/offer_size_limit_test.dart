import 'package:apex_file_share/core/protocol/transfer_rules.dart';
import 'package:apex_file_share/features/receive/logic/offer.dart';
import 'package:flutter_test/flutter_test.dart';

Offer _offer(List<OfferedFile> files) =>
    Offer(senderAddress: '192.168.1.20', senderId: 'phone', senderName: 'Phone', files: files);

void main() {
  test('sizes whose sum overflows are refused, not counted as zero', () {
    const max = 0x7fffffffffffffff;
    final offer = _offer(const [OfferedFile('a', max), OfferedFile('b', max), OfferedFile('c', 2)]);
    expect(checkOffer(offer, freeBytes: 1000), OfferProblem.badSize,
        reason: 'The sum wrapped to ${offer.totalBytes} and passed the free-space check.');
  });

  test('one file over the size limit is refused, even when free space is unknown', () {
    expect(checkOffer(_offer(const [OfferedFile('a', TransferRules.maxFileBytes + 1)]), freeBytes: null),
        OfferProblem.badSize);
    expect(checkOffer(_offer(const [OfferedFile('a', TransferRules.maxFileBytes)]), freeBytes: null),
        isNull);
  });

  test('the largest batch allowed still adds up to a true positive total', () {
    final offer = _offer(List.generate(
        TransferRules.maxFilesPerBatch, (i) => OfferedFile('f$i', TransferRules.maxFileBytes)));
    expect(checkOffer(offer, freeBytes: null), isNull);
    expect(offer.totalBytes, TransferRules.maxFilesPerBatch * TransferRules.maxFileBytes);
    expect(offer.totalBytes, greaterThan(0));
  });
}
