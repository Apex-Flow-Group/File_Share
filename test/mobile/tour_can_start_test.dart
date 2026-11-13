import 'package:apex_file_share/mobile/screens/tour_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision: only where permissions are asked (Android) does the tour
/// wait for the agreement; on Windows and Linux it starts at once.
void main() {
  test('where permissions are asked, start waits for the agreement', () {
    expect(tourCanStart(asksPermissions: true, agreed: false), isFalse);
    expect(tourCanStart(asksPermissions: true, agreed: true), isTrue);
  });

  test('where none are asked, start works without one', () {
    expect(tourCanStart(asksPermissions: false, agreed: false), isTrue);
  });
}
