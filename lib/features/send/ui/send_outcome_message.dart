import 'package:flutter/widgets.dart';

import '../../../core/protocol/transfer_rules.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/apex_snackbar.dart';
import '../data/send_http.dart';

/// What the user reads when a send ends. [sent] and [failed] differ by screen
/// (a file or an app); every other reason reads the same everywhere.
String sendOutcomeMessage(
  AppLocalizations l10n,
  SendOutcome outcome, {
  required String sent,
  required String failed,
}) =>
    switch (outcome) {
      SendOutcome.sent => sent,
      SendOutcome.failed => failed,
      SendOutcome.updateRequired => l10n.updateRequired,
      SendOutcome.declined => l10n.sendDeclined,
      SendOutcome.noAnswer => l10n.sendNoAnswer,
      SendOutcome.busy => l10n.sendReceiverBusy,
      SendOutcome.tooManyFiles => l10n.sendTooManyFiles(TransferRules.maxFilesPerBatch),
      SendOutcome.noSpace => l10n.sendNoSpace,
      SendOutcome.keyChanged => l10n.requestNewKey,
      SendOutcome.cancelled => l10n.sendCancelled,
    };

/// Shows how a send ended; true when everything was sent.
bool showSendOutcome(
  BuildContext context,
  SendOutcome outcome, {
  required String sent,
  required String failed,
}) {
  final ok = outcome == SendOutcome.sent;
  ApexSnackBar.result(context,
      ok: ok,
      successMessage: sent,
      failMessage: sendOutcomeMessage(AppLocalizations.of(context), outcome, sent: sent, failed: failed));
  return ok;
}
