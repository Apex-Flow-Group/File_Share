import 'package:apex_file_share/features/send/data/send_http.dart';
import 'package:apex_file_share/features/send/send_notice.dart';
import 'package:flutter_test/flutter_test.dart';

/// The desktop notice follows how the send ended. It once said "send failed"
/// for every result but sent, even when the user cancelled.
void main() {
  test('sent says it was sent', () {
    expect(sendNoticeFor(SendOutcome.sent), SendNotice.sent);
  });

  test('the user cancelling gives no notice', () {
    expect(sendNoticeFor(SendOutcome.cancelled), isNull);
  });

  test('the other device refusing says it was declined', () {
    expect(sendNoticeFor(SendOutcome.declined), SendNotice.declined);
  });

  test('every other result says the send failed', () {
    final others = SendOutcome.values.where((o) =>
        o != SendOutcome.sent &&
        o != SendOutcome.cancelled &&
        o != SendOutcome.declined);
    expect(others, isNotEmpty);
    for (final o in others) {
      expect(sendNoticeFor(o), SendNotice.failed, reason: '$o');
    }
  });
}
