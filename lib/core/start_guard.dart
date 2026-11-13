/// One start at a time: a second call while one runs waits for it instead
/// of opening the server and the discovery socket again.
class OneAtATime {
  Future<void>? _running;

  Future<void> run(Future<void> Function() start) =>
      _running ??= start().whenComplete(() => _running = null);
}

/// Runs [open]; if it fails, [close] undoes what it opened before the
/// failure, so a retry binds afresh, and the failure is rethrown.
Future<void> openOrUndo(
    Future<void> Function() open, Future<void> Function() close) async {
  try {
    await open();
  } catch (_) {
    await close();
    rethrow;
  }
}

enum FindDevices { search, start, wait }

/// What "find devices" does: searching needs the system running; after a
/// failed start it starts it again (owner decision); during the first start
/// it waits for it.
FindDevices findDevicesAction({required bool isRunning, required bool startFailed}) {
  if (isRunning) {
    return FindDevices.search;
  }
  return startFailed ? FindDevices.start : FindDevices.wait;
}
