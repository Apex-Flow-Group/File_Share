import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../core/protocol/transfer_rules.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../services/clipboard_monitor_service.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../shared/apex_snackbar.dart';
import '../../../shared/file_open_message.dart';
import '../../../shared/folder_open_message.dart';
import '../../../shared/framed_capsule_input.dart';
import '../../../utils/file_utils.dart';
import '../../send/data/send_http.dart';
import '../logic/chat_key.dart';
import '../logic/chat_store.dart';
import 'chat_files_bubble.dart';
import 'chat_outcome_message.dart';
import 'composer_tiles.dart';

/// One device's chat. The TV shows it read only: no writing line, no copy.
class DeviceChatView extends StatefulWidget {
  const DeviceChatView({
    required this.store,
    required this.device,
    this.canWrite = true,
    this.pickFiles,
    this.sendFiles,
    this.autofocus = false,
    this.initialText,
    this.initialFiles = const [],
    this.copied,
    this.onCopiedUsed,
    this.extras = const [],
    super.key,
  });

  final ChatStore store;
  final Device device;

  /// False on the TV: it only receives and shows.
  final bool canWrite;

  /// Picks files for the box; none on the TV, which does not write.
  final Future<List<String>> Function()? pickFiles;

  /// Sends files to [device]; they show as a line of the chat.
  final Future<SendOutcome> Function(List<String> paths)? sendFiles;

  /// Opened from the card's writing line: the keyboard comes up at once.
  final bool autofocus;

  /// What the card's paste put in the box, not sent yet.
  final String? initialText;

  /// Files the card's clip picked, in the box, not sent yet.
  final List<String> initialFiles;

  /// What was just copied on a computer, offered above the box to add.
  final ClipboardItem? copied;

  /// The copied item was added and sent, or dropped: it is no longer offered.
  final void Function({required bool sent})? onCopiedUsed;

  /// The card's other sends, as circles of the box (owner decision).
  final List<CapsuleAction> extras;

  @override
  State<DeviceChatView> createState() => _DeviceChatViewState();
}

class _DeviceChatViewState extends State<DeviceChatView> {
  ChatKey get _key => widget.device.chatKey;
  ChatPeer get _peer => widget.device.chatPeer;

  late final _text = TextEditingController(text: widget.initialText);
  late final _files = [for (final p in widget.initialFiles) ComposerFile(p)];

  /// The copy last offered or added, by identity: a new copy is offered.
  ClipboardItem? _seen;

  /// Offered above the box, not added yet.
  ClipboardItem? _offered;

  @override
  void initState() {
    super.initState();
    _offerCopied();
    // After the frame: inside a card, marking read rebuilds the card's own
    // head and row, which are being built right now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.store.opened(_key);
      }
    });
  }

  @override
  void didUpdateWidget(DeviceChatView old) {
    super.didUpdateWidget(old);
    if (!identical(widget.copied, _seen)) {
      setState(_offerCopied);
    }
  }

  @override
  void dispose() {
    widget.store.closed(_key);
    _text.dispose();
    super.dispose();
  }

  /// A new copy is offered above the box with a floating add button.
  void _offerCopied() {
    _seen = widget.copied;
    _offered = widget.copied;
  }

  /// Copied text goes in the box, as a paste: there it is seen before it is
  /// sent. A picture or files become tiles of the box.
  void _addCopied() {
    final item = _offered;
    if (item == null) {
      return;
    }
    setState(() {
      _offered = null;
      if (item.type == ClipboardItemType.text) {
        final text = item.text ?? '';
        _text.text = _text.text.isEmpty ? text : '${_text.text} $text';
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      } else {
        _files.addAll([for (final p in item.paths) ComposerFile(p, fromClipboard: true)]);
      }
    });
    if (item.type == ClipboardItemType.text) {
      widget.onCopiedUsed?.call(sent: true);
    }
  }

  void _dropCopied() {
    setState(() => _offered = null);
    widget.onCopiedUsed?.call(sent: false);
  }

  void _remove(ComposerFile f) {
    setState(() => _files.remove(f));
    if (f.fromClipboard && !_files.any((c) => c.fromClipboard)) {
      widget.onCopiedUsed?.call(sent: false);
    }
  }

  Future<void> _attach() async {
    final picked = await widget.pickFiles?.call() ?? const <String>[];
    if (picked.isNotEmpty && mounted) {
      setState(() => _files.addAll([for (final p in picked) ComposerFile(p)]));
    }
  }

  /// A text over the limit stays in the line with the reason, so nothing is
  /// cut off unseen (a field limit would silently drop the end of a paste).
  bool _send(String text) {
    final l10n = AppLocalizations.of(context);
    if (text.runes.length > TransferRules.chatTextLimit) {
      ApexSnackBar.error(context, l10n.chatTooLong(TransferRules.chatTextLimit));
      return false;
    }
    final added = List.of(_files);
    // One transfer at a time, as on the device card: the box keeps it all.
    if (added.isNotEmpty && TransferProgressService().isTransferring) {
      ApexSnackBar.info(context, l10n.chatTransferBusy);
      return false;
    }
    if (added.isNotEmpty) {
      setState(() => _files.removeWhere(added.contains));
    }
    _sendInOrder(text.trim().isEmpty ? null : text, added);
    return true;
  }

  /// The text first, then the files once it has arrived (owner decision):
  /// sent together, the first message's "accept chat?" held the other
  /// device's one question, and the files were turned away as busy. Text
  /// that did not arrive keeps the files in the box, unsent.
  Future<void> _sendInOrder(String? text, List<ComposerFile> files) async {
    if (text != null) {
      final outcome = await widget.store.write(widget.device, text);
      if (outcome != ChatOutcome.sent) {
        if (files.isNotEmpty && mounted) {
          setState(() => _files.insertAll(0, files));
        }
        return;
      }
    }
    if (files.isEmpty) {
      return;
    }
    final outcome = await widget.sendFiles?.call([for (final f in files) f.path]);
    if (files.any((f) => f.fromClipboard)) {
      // The copy is deleted only once it arrived: a failed line keeps it,
      // and its retry with it.
      widget.onCopiedUsed?.call(sent: outcome == SendOutcome.sent);
    }
  }

  Future<void> _open(ChatFile f) async {
    // Another file may have taken the name since (deleted, then a new one
    // arrived): a different size means it is not this line's file.
    final file = File(f.path);
    if (!file.existsSync() || file.lengthSync() != f.size) {
      ApexSnackBar.error(context, AppLocalizations.of(context).fileMissing);
      return;
    }
    try {
      await FileUtils.openFile(f.path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(context, fileOpenMessage(e, AppLocalizations.of(context)));
      }
    }
  }

  Future<void> _openFolder(ChatFile f) async {
    try {
      await FileUtils.openFileLocation(f.path);
    } catch (e) {
      if (mounted) {
        ApexSnackBar.error(context, folderOpenMessage(e, AppLocalizations.of(context)));
      }
    }
  }

  /// One transfer at a time, as on the device card.
  void _retryFiles(ChatMessage m) {
    if (TransferProgressService().isTransferring) {
      ApexSnackBar.info(context, AppLocalizations.of(context).chatTransferBusy);
      return;
    }
    widget.store.retryFiles(widget.device, m);
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
        final messages = widget.store.thread(_key)?.messages ?? const <ChatMessage>[];
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
                      itemBuilder: (context, i) {
                        final m = messages[messages.length - 1 - i];
                        return m.isFiles
                            ? ChatFilesBubble(
                                message: m,
                                canOpenFolder: widget.canWrite,
                                canRetry: widget.canWrite,
                                onOpen: _open,
                                onOpenFolder: _openFolder,
                                onRetry: _retryFiles,
                              )
                            : _Bubble(
                                message: m,
                                canCopy: widget.canWrite,
                                onCopy: _copy,
                                onRetry: (m) => widget.store.retry(widget.device, m),
                              );
                      },
                    ),
            ),
            if (widget.store.isBlocked(_peer)) ...[
              const SizedBox(height: 8),
              Text(l10n.chatBlocked,
                  textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
              // On the TV too, reached by the remote: the one place to
              // unblock on every device.
              TextButton(
                onPressed: () => widget.store.unblock(_peer),
                child: Text(l10n.chatUnblock),
              ),
            ] else if (widget.canWrite) ...[
              if (_offered != null) ...[
                const SizedBox(height: 8),
                CopiedSuggestion(item: _offered!, onAdd: _addCopied, onDismiss: _dropCopied),
              ],
              const SizedBox(height: 8),
              FramedCapsuleInput(
                hint: l10n.chatHint,
                sendLabel: l10n.send,
                onSend: _send,
                controller: _text,
                hasAttachments: _files.isNotEmpty,
                onAttach: widget.pickFiles == null ? null : _attach,
                attachLabel: l10n.chatAttach,
                autofocus: widget.autofocus || widget.initialText != null || widget.initialFiles.isNotEmpty,
                pasteLabel: l10n.chatPaste,
                extras: widget.extras,
                onPasteEmpty: () => ApexSnackBar.info(context, l10n.chatClipboardEmpty),
                top: _files.isEmpty
                    ? null
                    : ComposerTiles(files: _files, onRemove: _remove),
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
      ChatOutcome.declined || ChatOutcome.updateRequired || ChatOutcome.tooLong || ChatOutcome.keyChanged => false,
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
