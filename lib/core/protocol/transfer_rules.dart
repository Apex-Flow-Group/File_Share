/// Limits of one transfer, defined here once.
class TransferRules {
  TransferRules._();

  /// Owner decision (2026-10-23): a bigger batch is refused whole.
  static const maxFilesPerBatch = 1000;

  /// Largest size one offered file may claim (1 PiB). No real file comes
  /// near it; it keeps the sum of a full batch inside a 64-bit int, so huge
  /// claimed sizes cannot wrap the total to zero and pass the space check.
  static const maxFileBytes = 1 << 50;

  /// Largest offer body (the list of names and sizes) the receiver reads.
  static const offerBodyLimit = 1024 * 1024;

  /// How long the receiver waits for the user to accept or refuse.
  static const decisionTimeout = Duration(seconds: 30);

  /// A request body (offer or file) that sends nothing for this long is
  /// dropped, so a stalled sender cannot hold the door or its batch open.
  static const bodyIdleLimit = Duration(seconds: 60);

  /// Tokens of an accepted batch expire when no file starts for this long.
  static const tokenIdleLimit = Duration(minutes: 5);
}
