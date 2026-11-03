/// Messages between two phones over Nearby, as BYTES payloads in JSON.
/// The sender offers the whole batch; the receiver answers with one token per
/// accepted file; each FILE payload is then announced with its token.
class NearbyMessage {
  NearbyMessage._();

  /// {type, version, name, files: [{name, size}]}
  static const offer = 'offer';

  /// {type, accepted, tokens?, error?}
  static const answer = 'answer';

  /// {type, token, payload_id}
  static const file = 'file';
}
