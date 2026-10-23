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

  static bool accepts(String? sentVersion) => sentVersion == '$version';
}
