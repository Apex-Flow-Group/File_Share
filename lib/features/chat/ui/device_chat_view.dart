import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../core/protocol/transfer_rules.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../services/clipboard_monitor_service.dart';
import '../../../shared/apex_snackbar.dart';
import '../../../shared/framed_capsule_input.dart';
import '../../send/data/send_http.dart';
import '../logic/chat_store.dart';
import 'chat_outcome_message.dart';

/// One device's chat. The TV shows it read only: no writing line, no copy.
class DeviceChatView extends StatefulWidget {
  const DeviceChatView({
    required this.store,
    required this.device,
    this.canWrite = true,
    super.key,
  });

  final ChatStore store;
  final Device device;

  /// False on the TV: it only receives and shows.
  final bool canWrite;

  @override
  State<DeviceChatView> createState() => _DeviceChatViewState();
}

class _DeviceChatViewState extends State<DeviceChatView> {
  String get _address => widget.device.ip;

  @override
  void initState() {
    super.initState();
    widget.store.opened(_address);
  }

  @override
  void dispose() {
    widget.store.closed(_address);
    super.dispose();
  }

  /// A text over the limit stays in the line with the reason, so nothing is
  /// cut off unseen (a field limit would silently drop the end of a paste).
  bool _send(String text) {
    if (text.runes.length > TransferRules.chatTextLimit) {
      ApexSnackBar.error(context, AppLocalizations.of(context).chatTooLong(TransferRules.chatTextLimit));
      return false;
    }
    widget.store.write(widget.device, text);
    return true;
  }

  Future<void> _copy(String text) async {
    await ClipboardMonitorService.instance.copyText(text);
    if (mounted) {
      ApexSnackBar.success(context, AppLocalizations.of(context).textCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final messages = widget.store.thread(_address)?.messages ?? const <ChatMessage>[];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: messages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(l10n.chatEmpty, style: TextStyle(color: Theme.of(context).hintColor)),
                    )
                  : ListView.builder(
                      reverse: true,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: messages[messages.length - 1 - i],
                        canCopy: widget.canWrite,
                        onCopy: _copy,
                        onRetry: (m) => widget.store.retry(widget.device, m),
                      ),
                    ),
            ),
            if (widget.store.isBlocked(_address)) ...[
              const SizedBox(height: 8),
              Text(l10n.chatBlocked,
                  textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
              // The TV has its own buttons, reached by the remote.
              if (widget.canWrite)
                TextButton(
                  onPressed: () => widget.store.unblock(_address),
                  child: Text(l10n.chatUnblock),
                ),
            ] else if (widget.canWrite) ...[
              const SizedBox(height: 8),
              FramedCapsuleInput(
                hint: l10n.chatHint,
                sendLabel: l10n.send,
                onSend: _send,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Retry is offered only where it can work: a refusal holds until the other
/// app closes, and another version or a too-long text fails the same way again.
bool _retryHelps(ChatOutcome failure) => switch (failure) {
      ChatOutcome.failed || ChatOutcome.noAnswer || ChatOutcome.busy => true,
      ChatOutcome.declined || ChatOutcome.updateRequired || ChatOutcome.tooLong => false,
      ChatOutcome.sent => false,
    };

const _textStyle = TextStyle(fontSize: 15, height: 1.35);

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.canCopy,
    required this.onCopy,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool canCopy;
  final void Function(String) onCopy;
  final void Function(ChatMessage) onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mine = message.mine;
    final failed = message.status == ChatStatus.failed;
    final background = mine
        ? scheme.primary.withValues(alpha: isDark ? 0.35 : 0.14)
        : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F2));
    // Each message keeps its own direction: an English line inside an
    // Arabic screen still reads left to right.
    final direction = Bidi.detectRtlDirectionality(message.text) ? TextDirection.rtl : TextDirection.ltr;

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                  border: failed ? Border.all(color: Colors.red.withValues(alpha: 0.6)) : null,
                ),
                // The TV has no copy, so nothing there can be selected either.
                child: canCopy
                    ? SelectableText(message.text, textDirection: direction, style: _textStyle)
                    : Text(message.text, textDirection: direction, style: _textStyle),
              ),
              if (!mine && canCopy)
                TextButton.icon(
                  onPressed: () => onCopy(message.text),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l10n.chatCopy),
                ),
              if (mine && message.status == ChatStatus.sending)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child:
                      Text(l10n.sending, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ),
              if (failed) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(chatOutcomeMessage(l10n, message.failure!),
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
                if (_retryHelps(message.failure!))
                  TextButton.icon(
                    onPressed: () => onRetry(message),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.retry),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
