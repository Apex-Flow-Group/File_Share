/// The wire protocol between two copies of the app. Built new: a request with
/// no version, or another version, is refused before anything is read.
class ApexProtocol {
  ApexProtocol._();

  static const version = 3;

  static const versionHeader = 'x-apex-version';
  static const tokenHeader = 'x-apex-token';

  static const pingPath = '/ping';
  static const offerPath = '/offer';
  static const uploadPath = '/upload';

  /// Error code of a version refusal; the sender shows "update the app".
  static const updateRequired = 'update_required';

  /// Why an offer was not accepted when the user never answered (a refusal
  /// carries no reason). The sender must not report it as a refusal.
  static const noAnswer = 'no_answer';

  static bool accepts(String? sentVersion) => sentVersion == '$version';
}
