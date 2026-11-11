import '../../../core/protocol/transfer_rules.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../send/data/send_http.dart';

/// Why a chat message did not arrive, shown under it.
String chatOutcomeMessage(AppLocalizations l10n, ChatOutcome outcome) => switch (outcome) {
      ChatOutcome.sent => '',
      ChatOutcome.failed => l10n.chatFailed,
      ChatOutcome.updateRequired => l10n.updateRequired,
      ChatOutcome.declined => l10n.chatDeclined,
      ChatOutcome.noAnswer => l10n.sendNoAnswer,
      ChatOutcome.busy => l10n.sendReceiverBusy,
      ChatOutcome.tooLong => l10n.chatTooLong(TransferRules.chatTextLimit),
      ChatOutcome.keyChanged => l10n.requestNewKey,
    };
