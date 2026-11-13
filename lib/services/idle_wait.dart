import 'dart:async';

/// Waits until [busy] is false, then calls [done] once. A second start while
/// one waits is ignored: two waits would each open the install sheet.
class IdleWait {
  Timer? _timer;

  void start(bool Function() busy, void Function() done,
      {Duration every = const Duration(seconds: 2)}) {
    if (_timer?.isActive ?? false) {
      return;
    }
    _timer = Timer.periodic(every, (t) {
      if (!busy()) {
        t.cancel();
        done();
      }
    });
  }
}
