import 'data/send_http.dart';

/// What the desktop notification says about a send.
enum SendNotice { sent, declined, failed }

/// The notice for [outcome]; `null` when the user cancelled, who knows.
SendNotice? sendNoticeFor(SendOutcome outcome) => switch (outcome) {
      SendOutcome.sent => SendNotice.sent,
      SendOutcome.cancelled => null,
      SendOutcome.declined => SendNotice.declined,
      _ => SendNotice.failed,
    };
