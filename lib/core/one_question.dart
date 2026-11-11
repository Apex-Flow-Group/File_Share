/// One question to the user at a time, shared by every door (files, chat,
/// shared folder). Others are refused as busy, so dialogs never pile up and a
/// new one cannot appear under the finger that is about to press Accept.
class OneQuestion {
  bool _busy = false;

  /// False when another question is already waiting for the user.
  bool take() {
    if (_busy) {
      return false;
    }
    _busy = true;
    return true;
  }

  void release() => _busy = false;
}
