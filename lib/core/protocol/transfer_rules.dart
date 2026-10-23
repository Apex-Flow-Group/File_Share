/// Limits of one transfer, defined here once.
class TransferRules {
  TransferRules._();

  /// Owner decision (2026-10-23): a bigger batch is refused whole.
  static const maxFilesPerBatch = 1000;

  /// Largest offer body (the list of names and sizes) the receiver reads.
  static const offerBodyLimit = 1024 * 1024;

  /// How long the receiver waits for the user to accept or refuse.
  static const decisionTimeout = Duration(seconds: 30);

  /// Tokens of an accepted batch expire when no file starts for this long.
  static const tokenIdleLimit = Duration(minutes: 5);
}
