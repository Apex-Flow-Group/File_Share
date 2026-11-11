import '../../../core/protocol/transfer_rules.dart';

class OfferedFile {
  const OfferedFile(this.name, this.size);

  /// Already cleaned with safeFileName.
  final String name;
  final int size;
}

/// What a sender asks to send. [senderAddress] comes from the connection,
/// never from the request body.
class Offer {
  const Offer({
    required this.senderAddress,
    required this.senderId,
    required this.senderName,
    required this.files,
  });

  final String senderAddress;

  /// The id the sender gave, already cleaned: its files go to the chat of
  /// this id at [senderAddress].
  final String senderId;
  final String senderName;
  final List<OfferedFile> files;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);
}

enum OfferProblem { noFiles, tooManyFiles, badSize, notEnoughSpace }

/// The whole batch is refused before the user is asked and before any byte is
/// written. [freeBytes] is null when the free space is unknown.
OfferProblem? checkOffer(Offer offer, {required int? freeBytes}) {
  if (offer.files.isEmpty) {
    return OfferProblem.noFiles;
  }
  if (offer.files.length > TransferRules.maxFilesPerBatch) {
    return OfferProblem.tooManyFiles;
  }
  if (offer.files.any((f) => f.size < 0 || f.size > TransferRules.maxFileBytes)) {
    return OfferProblem.badSize;
  }
  if (freeBytes != null && offer.totalBytes > freeBytes) {
    return OfferProblem.notEnoughSpace;
  }
  return null;
}
