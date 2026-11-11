/// The wire protocol between two copies of the app. Built new: a request with
/// no version, or another version, is refused before anything is read.
class ApexProtocol {
  ApexProtocol._();

  static const version = 5;

  static const versionHeader = 'x-apex-version';
  static const tokenHeader = 'x-apex-token';

  static const pingPath = '/ping';
  static const offerPath = '/offer';
  static const uploadPath = '/upload';
  static const chatPath = '/chat';

  /// Error code of a version refusal; the sender shows "update the app".
  static const updateRequired = 'update_required';

  /// Why an offer was not accepted when the user never answered (a refusal
  /// carries no reason). The sender must not report it as a refusal.
  static const noAnswer = 'no_answer';

  /// The certificate the request came with is not the one discovery heard
  /// from the device it claims to be. Refused before the user is asked.
  static const wrongIdentity = 'wrong_identity';

  /// A chat message over TransferRules.chatTextLimit.
  static const tooLong = 'too_long';

  /// The answer, with 200, to a device turned away: a refused or blocked
  /// offer or chat message, and a file of a batch whose sender was blocked
  /// while it moved. The sender reads "refused" from it, never "cancelled".
  static const Map<String, Object> refusal = {'accepted': false};

  static bool isRefusal(int status, Object? json) =>
      status == 200 && json is Map && json['accepted'] == false && json['reason'] == null;

  static bool accepts(String? sentVersion) => sentVersion == '$version';
}
