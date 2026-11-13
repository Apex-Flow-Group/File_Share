import 'package:apex_file_share/services/idle_wait.dart';
import 'package:flutter_test/flutter_test.dart';

/// An update ready during a transfer waits for it once: a second wait (the
/// about tile, a return to the app) would open the install sheet twice.
void main() {
  const tick = Duration(milliseconds: 5);

  test('two starts while busy end in one call', () async {
    var busy = true;
    var done = 0;
    final wait = IdleWait()
      ..start(() => busy, () => done++, every: tick)
      ..start(() => busy, () => done++, every: tick);
    await Future<void>.delayed(tick * 4);
    expect(done, 0, reason: 'still busy');
    busy = false;
    await Future<void>.delayed(tick * 4);
    expect(done, 1);
    wait.start(() => false, () => done++, every: tick);
    await Future<void>.delayed(tick * 4);
    expect(done, 2, reason: 'a later wait runs again');
  });
}
