import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/apex_core.dart';
import '../../features/chat/logic/chat_key.dart';
import '../../features/chat/ui/chat_attach.dart';
import '../../features/chat/ui/confirm_block.dart';
import '../../features/clipboard/ui/clipboard_label.dart';
import '../../features/send/data/send_http.dart';
import '../../features/send/ui/send_outcome_message.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../services/clipboard_monitor_service.dart';
import '../../services/desktop_notification_service.dart';
import '../../services/transfer_progress_service.dart';
import '../../shared/apex_snackbar.dart';
import '../../shared/device_look.dart';
import '../../shared/framed_capsule_input.dart';
import '../../utils/path_name.dart';
import '../../utils/platform_detector.dart';
import '../screens/share_browser_screen.dart';
import 'chat_card_parts.dart';
import 'connection_send_actions.dart';
import 'transfer_progress_indicator.dart';

enum _Status { idle, sending }

/// One opened chat card at a time: opening another folds it (owner decision).
final _openChat = ValueNotifier<ChatKey?>(null);

@visibleForTesting
void foldChatCards() => _openChat.value = null;

/// Opens the card of the device with [key], folding any other.
void openChatCard(ChatKey key) => _openChat.value = key;

class ConnectionWidget extends StatefulWidget {
  final Device device;
  final bool isActive;
  final bool isPinned;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final String? pendingFilePath;
  final VoidCallback? onPendingFileSent;
  final List<String>? pendingSharedFiles;
  final VoidCallback? onSharedFilesSent;
  final ClipboardItem? pendingClipboardItem;
  final VoidCallback? onClipboardItemSent;
  final bool isGloballyBusy;
  const ConnectionWidget({
    required this.device,
    this.isActive = true,
    this.isPinned = false,
    this.onPin,
    this.onUnpin,
    this.pendingFilePath,
    this.onPendingFileSent,
    this.pendingSharedFiles,
    this.onSharedFilesSent,
    this.pendingClipboardItem,
    this.onClipboardItemSent,
    this.isGloballyBusy = false,
    super.key,
  });

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget>
    with SingleTickerProviderStateMixin, ConnectionSendActions {
  _Status _status = _Status.idle;
  bool _cancelledByUser = false;
  late AnimationController _sendAnim;

  @override
  Device get device => widget.device;
  @override
  void setSending() => setState(() => _status = _Status.sending);
  @override
  void setIdle() => setState(() => _status = _Status.idle);

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final svc = TransferProgressService();
    if (svc.isSending &&
        svc.isTransferring &&
        svc.targetDeviceId == widget.device.id) {
      _status = _Status.sending;
    }
    svc.progressStream.listen((p) {
      if (!mounted) {
        return;
      }
      if (_cancelledByUser) {
        if (p == null) {
          _cancelledByUser = false;
        }
        return;
      }
      if (p == null && _status == _Status.sending) {
        setState(() => _status = _Status.idle);
      }
    });
  }

  @override
  void dispose() {
    _sendAnim.dispose();
    _cardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    // Another version is listed but nothing is sent to it.
    final usable = widget.isActive && !widget.device.versionMismatch;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: usable ? 1.0 : 0.45,
        child: Padding(
          padding: const EdgeInsets.all(16),
          // A network device is a chat (owner decision); the rest keep the card.
          child: usable && widget.device.isMdns
              ? _buildChatCard(l10n, isDark)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 14),
                    ..._banners(l10n, usable),
                    // Offline first, as on the TV: it is what the device is now.
                    if (!widget.isActive)
                      _buildOfflineBar(l10n)
                    else if (widget.device.versionMismatch)
                      _buildVersionBar(l10n)
                    else
                      _status == _Status.sending
                          ? _buildSendingState()
                          : _buildActions(l10n, isDark),
                  ],
                ),
        ),
      ),
    );
  }

  /// [withClipboard] false on a chat card: what was copied shows inside the
  /// writing line there (owner decision).
  List<Widget> _banners(AppLocalizations l10n, bool usable, {bool withClipboard = true}) {
    final idle = usable && _status == _Status.idle && !widget.isGloballyBusy;
    return [
      if (idle &&
          widget.pendingSharedFiles != null &&
          widget.pendingSharedFiles!.isNotEmpty)
        _buildSharedFilesBanner(l10n),
      if (idle && widget.pendingFilePath != null) _buildPendingFileBanner(l10n),
      if (withClipboard && idle && widget.pendingClipboardItem != null)
        _ClipboardBanner(
          item: widget.pendingClipboardItem!,
          onSend: _sendClipboardItem,
          onDismiss: widget.onClipboardItemSent,
        ),
    ];
  }

  // ─── Chat card ────────────────────────────────────────────────────────────

  /// What the card's paste took from the clipboard, for the writing line.
  String? _paste;

  /// What the row's clip picked, for the message box.
  List<String> _picked = const [];

  /// A new paste or pick rebuilds the message box with it.
  int _pasteSeq = 0;

  bool get _expanded => _openChat.value == widget.device.chatKey;

  /// Holds the opened card, so back knows whether its box is being written in.
  final _cardFocus = FocusNode(skipTraversal: true, canRequestFocus: false);

  /// Back, one step at a time (owner decision): the system closes the
  /// keyboard, then the box is left, then the card folds.
  void _back(bool didPop, Object? _) {
    if (didPop) {
      return;
    }
    if (_cardFocus.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      _openChat.value = null;
    }
  }

  void _open({String? paste, List<String> picked = const []}) {
    setState(() {
      _paste = paste;
      _picked = picked;
      _pasteSeq++;
    });
    _openChat.value = widget.device.chatKey;
  }

  void _toggle() => _expanded ? _openChat.value = null : _open();

  /// Reads the clipboard only now, on the user's press (owner decision).
  Future<void> _pasteFromRow() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted) {
      return;
    }
    if (text == null || text.isEmpty) {
      ApexSnackBar.info(
          context, AppLocalizations.of(context).chatClipboardEmpty);
      return;
    }
    _open(paste: text);
  }

  /// The clip adds, it does not send: the card opens with the files in the
  /// message box, sent with its send button.
  Future<void> _attachFromRow() async {
    final picked = await pickFilePaths();
    if (picked.isNotEmpty && mounted) {
      _open(picked: picked);
    }
  }

  /// The copy was added and sent, or dropped: it is no longer offered.
  void _copiedUsed({required bool sent}) {
    widget.onClipboardItemSent?.call();
    if (sent) {
      ClipboardMonitorService.instance.cleanupTempImages();
    }
  }

  /// Whether the head's menu is open: its ⋮ shows ✕ then (capsule-ui §4).
  bool _menuOpen = false;

  /// The menu and the fold arrow side by side are one filled capsule
  /// (capsule-ui §1), a step lighter than the card, no border and no glow
  /// on a card. A touch on the arrow reaches the head, which folds.
  Widget _headCapsule(AppLocalizations l10n) {
    final c = FramedCapsuleColors.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(color: c.circle, borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _headMenu(l10n, c),
        SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.expand_less_rounded, color: c.onCircle),
        ),
      ]),
    );
  }

  void _menuShut() => setState(() => _menuOpen = false);

  /// The opened card's head keeps one menu beside the fold arrow (owner
  /// decision): three buttons there left the name a few letters wide.
  /// Block is last, apart and red.
  Widget _headMenu(AppLocalizations l10n, FramedCapsuleColors c) {
    final store = ApexCore.instance.chat;
    final canPin = widget.isPinned ? widget.onUnpin != null : widget.onPin != null;
    return PopupMenuButton<_HeadAction>(
      tooltip: l10n.deviceOptions,
      color: c.circle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onOpened: () => setState(() => _menuOpen = true),
      onCanceled: _menuShut,
      // ⋮ in a narrower button, so the capsule stays small (capsule-ui §3).
      child: SizedBox(
        width: 40,
        height: 48,
        child: Icon(_menuOpen ? Icons.close_rounded : Icons.more_vert_rounded, color: c.onCircle),
      ),
      onSelected: (action) async {
        _menuShut();
        switch (action) {
          case _HeadAction.share:
            _openShareBrowser();
          case _HeadAction.pin:
            (widget.isPinned ? widget.onUnpin : widget.onPin)?.call();
          case _HeadAction.block:
            if (await confirmBlock(context, widget.device.name)) {
              store.block(widget.device.chatPeer);
            }
        }
      },
      itemBuilder: (context) {
        final canBlock = store.canBlock(widget.device.chatPeer);
        return [
          if (widget.device.hasShare)
            PopupMenuItem(
              value: _HeadAction.share,
              child: ListTile(
                leading: const Icon(Icons.folder_shared_rounded, color: Color(0xFFFF9500)),
                title: Text(l10n.sharedFolder),
              ),
            ),
          if (canPin)
            PopupMenuItem(
              value: _HeadAction.pin,
              child: ListTile(
                // The icon draws what the item does, as on the TV card.
                leading: Icon(widget.isPinned ? Icons.star_border_rounded : Icons.star_rounded),
                title: Text(widget.isPinned ? l10n.unpinDevice : l10n.pinDevice),
              ),
            ),
          if (canBlock && (widget.device.hasShare || canPin)) const PopupMenuDivider(),
          if (canBlock)
            PopupMenuItem(
              value: _HeadAction.block,
              child: ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.red),
                title: Text(l10n.chatBlock, style: const TextStyle(color: Colors.red)),
              ),
            ),
        ];
      },
    );
  }

  Widget _buildChatCard(AppLocalizations l10n, bool isDark) =>
      ValueListenableBuilder<ChatKey?>(
        valueListenable: _openChat,
        builder: (context, open, _) {
          final banners = _banners(l10n, true, withClipboard: false);
          final copied = _status != _Status.idle || widget.isGloballyBusy ? null : widget.pendingClipboardItem;
          if (open != widget.device.chatKey) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChatProfileRow(
                  device: widget.device,
                  onOpen: _toggle,
                  onPaste: _pasteFromRow,
                  onAttach: _attachFromRow,
                ),
                if (banners.isNotEmpty) const SizedBox(height: 12),
                ...banners,
                if (_status == _Status.sending) ...[
                  const SizedBox(height: 12),
                  _buildSendingState()
                ],
              ],
            );
          }
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: _back,
            child: Focus(
            focusNode: _cardFocus,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Touching the head folds the card again.
              Semantics(
                button: true,
                label: l10n.chatClose,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Row(children: [
                    Expanded(child: _buildHeader(isDark, withStar: false)),
                    _headCapsule(l10n),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              ...banners,
              // The send buttons are circles of the message box now; only
              // a running send, or another device's, takes a row here.
              if (_status == _Status.sending) ...[
                _buildSendingState(),
                const SizedBox(height: 10),
              ] else if (widget.isGloballyBusy &&
                  TransferProgressService().targetDeviceId != widget.device.id) ...[
                _buildBusyBar(l10n),
                const SizedBox(height: 10),
              ],
              ChatCardPanel(
                key: ValueKey(_pasteSeq),
                device: widget.device,
                initialText: _paste,
                initialFiles: _picked,
                copied: copied,
                onCopiedUsed: _copiedUsed,
                extras: [
                  // The same choice the button row made: an app on a phone,
                  // a folder elsewhere.
                  if (PlatformDetector.instance.isMobile)
                    (icon: Icons.android_rounded, label: l10n.sendApp, onTap: sendApp)
                  else
                    (icon: Icons.folder_zip_rounded, label: l10n.sendFolder, onTap: sendFolder),
                ],
              ),
            ],
          ),
          ),
          );
        },
      );

  Widget _buildHeader(bool isDark, {bool withStar = true}) {
    final color = _deviceColor;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(_deviceIcon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── اسم الجهاز (قابل للتغيير) — خط عريض
              // The online dot before the name, over the transport badge
              // (owner decision), not at the row's end among the buttons.
              Row(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.isActive && !widget.device.versionMismatch
                        ? Colors.green
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.device.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              // ─── السطر الثاني: hostname (إن اختلف عن name) أو IP + badges
              const SizedBox(height: 3),
              if (widget.device.hostname != null &&
                  widget.device.hostname!.isNotEmpty &&
                  widget.device.hostname != widget.device.name) ...[
                // hostname مختلف عن الاسم — اعرضه بخط أصغر
                Text(
                  widget.device.hostname!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
              ],
              // ─── شارات النقل + IP
              Row(children: [
                // Another version gets its address only: no transport to offer.
                if (widget.isActive && !widget.device.versionMismatch) ...[
                  // Shrinks instead of overflowing with large system fonts.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: _TransportBadge(
                        isNearby: widget.device.isNearby,
                        isWifi: widget.device.isMdns,
                      ),
                    ),
                  ),
                  if (!widget.device.isNearby &&
                      widget.device.ip.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.device.ip,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ] else
                  Text(
                    widget.device.ip.isNotEmpty ? widget.device.ip : '—',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ]),
            ],
          ),
        ),
        // ─── زر المفضلة
        if (withStar && (widget.onPin != null || widget.onUnpin != null))
          Tooltip(
            message: widget.isPinned
                ? AppLocalizations.of(context).unpinDevice
                : AppLocalizations.of(context).pinDevice,
            child: GestureDetector(
              onTap: widget.isPinned ? widget.onUnpin : widget.onPin,
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: widget.isPinned
                      ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                      : (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  widget.isPinned
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 16,
                  color: widget.isPinned
                      ? color
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVersionBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.system_update_rounded, size: 16, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.updateRequired,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildOfflineBar(AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          isAr ? 'غير متصل حالياً' : 'Currently offline',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }

  Widget _buildPendingFileBanner(AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    final fileName = fileNameOf(widget.pendingFilePath!);
    return GestureDetector(
      onTap: _sendPendingFile,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.note_rounded, color: Colors.purple, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAr ? 'إرسال: $fileName' : 'Send: $fileName',
              style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.send_rounded, color: Colors.purple, size: 16),
        ]),
      ),
    );
  }

  Widget _buildSharedFilesBanner(AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    final files = widget.pendingSharedFiles!;
    final count = files.length;
    final label = count == 1
        ? fileNameOf(files.first)
        : (isAr ? '$count ملفات مشاركة' : '$count shared files');

    return GestureDetector(
      onTap: _sendSharedFiles,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6750A4).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF6750A4).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.share_rounded, color: Color(0xFF6750A4), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAr ? 'إرسال: $label' : 'Send: $label',
              style: const TextStyle(
                  color: Color(0xFF6750A4),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.send_rounded, color: Color(0xFF6750A4), size: 16),
        ]),
      ),
    );
  }

  Future<void> _sendPendingFile() async {
    final path = widget.pendingFilePath;
    if (path == null) {
      return;
    }
    setSending();
    try {
      final outcome = await ApexCore.instance.sendFile(path, widget.device);
      final ok = outcome == SendOutcome.sent;
      if (mounted) {
        showSendOutcome(context, outcome,
            sent: AppLocalizations.of(context).fileSentSuccess,
            failed: AppLocalizations.of(context).fileSendFailed);
        if (ok) {
          widget.onPendingFileSent?.call();
        }
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }

  Future<void> _sendSharedFiles() async {
    final paths = widget.pendingSharedFiles;
    if (paths == null || paths.isEmpty) {
      return;
    }
    setSending();
    try {
      final outcome = await ApexCore.instance.sendFiles(paths, widget.device);
      final ok = outcome == SendOutcome.sent;
      if (mounted) {
        showSendOutcome(context, outcome,
            sent: AppLocalizations.of(context).fileSentSuccess,
            failed: AppLocalizations.of(context).fileSendFailed);
        if (ok) {
          widget.onSharedFilesSent?.call();
        }
      }
      final label = paths.length == 1
          ? fileNameOf(paths.first)
          : '${paths.length} files';
      if (ok) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }

  Future<void> _sendClipboardItem() async {
    final item = widget.pendingClipboardItem;
    if (item == null) {
      return;
    }
    final label = clipboardLabel(AppLocalizations.of(context), item);
    setSending();
    try {
      final outcome = await ClipboardMonitorService.instance.withSendableFiles(
          item, (paths) => ApexCore.instance.sendFiles(paths, widget.device));
      final ok = outcome == SendOutcome.sent;
      if (mounted) {
        showSendOutcome(context, outcome,
            sent: AppLocalizations.of(context).fileSentSuccess,
            failed: AppLocalizations.of(context).fileSendFailed);
        if (ok) {
          widget.onClipboardItemSent?.call();
          // نظّف الصور المؤقتة بعد الإرسال الناجح
          await ClipboardMonitorService.instance.cleanupTempImages();
        }
      }
      if (ok) {
        await DesktopNotificationService.instance.showFileSent(label);
      } else {
        await DesktopNotificationService.instance.showSendFailed(label);
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }

  Widget _buildActions(AppLocalizations l10n, bool isDark) {
    final svc = TransferProgressService();
    final isThisDeviceTarget = svc.targetDeviceId == widget.device.id;
    if (widget.isGloballyBusy &&
        _status == _Status.idle &&
        !isThisDeviceTarget) {
      return _buildBusyBar(l10n);
    }
    return Row(
      children: [
        // Owner decision: on a network device the chat line's clip sends
        // files. A Nearby-only phone has no chat line, so it keeps this button.
        if (!widget.device.isMdns) ...[
          Expanded(
              child: _ActionButton(
            icon: Icons.upload_file_rounded,
            label: l10n.sendFilesNow,
            color: Theme.of(context).colorScheme.primary,
            isDark: isDark,
            onTap: sendFile,
          )),
          const SizedBox(width: 10),
        ],
        if (Platform.isAndroid)
          Expanded(
              child: _ActionButton(
            icon: Icons.android_rounded,
            label: l10n.sendApp,
            color: const Color(0xFF34C759),
            isDark: isDark,
            onTap: sendApp,
          ))
        else
          Expanded(
              child: _ActionButton(
            icon: Icons.folder_zip_rounded,
            label: l10n.sendFolder,
            color: const Color(0xFF5856D6),
            isDark: isDark,
            onTap: sendFolder,
          )),
        // زر المجلد المشترك — يظهر فقط إذا الجهاز desktop وأعلن عن Share
        if (widget.device.hasShare) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.folder_shared_rounded,
              label: l10n.sharedFolder,
              color: const Color(0xFFFF9500),
              isDark: isDark,
              onTap: _openShareBrowser,
            ),
          ),
        ],
      ],
    );
  }

  void _openShareBrowser() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareBrowserScreen(device: widget.device),
      ),
    );
  }

  Widget _buildBusyBar(AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          isAr ? 'يوجد إرسال جارٍ...' : 'Transfer in progress...',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }

  Widget _buildSendingState() {
    return TransferProgressIndicator(
      onCancel: () {
        _cancelledByUser = true;
        TransferProgressService().cancelTransfer();
        setState(() => _status = _Status.idle);
      },
    );
  }

  IconData get _deviceIcon => deviceIcon(widget.device);

  Color get _deviceColor => deviceColor(widget.device);
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Transport Badge ──────────────────────────────────────────────────────────

class _TransportBadge extends StatelessWidget {
  final bool isNearby;
  final bool isWifi;
  const _TransportBadge({required this.isNearby, required this.isWifi});

  @override
  Widget build(BuildContext context) {
    if (isNearby && isWifi) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _badge(context, const Color(0xFF34C759), Icons.sensors_rounded,
            AppLocalizations.of(context).directConnection),
        const SizedBox(width: 4),
        _badge(context, const Color(0xFF007AFF), Icons.wifi_rounded, 'WiFi'),
      ]);
    }
    if (isNearby) {
      return _badge(context, const Color(0xFF34C759), Icons.sensors_rounded,
          AppLocalizations.of(context).directConnection);
    }
    return _badge(context, const Color(0xFF007AFF), Icons.wifi_rounded, 'WiFi');
  }

  Widget _badge(
      BuildContext context, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ─── Clipboard Banner ─────────────────────────────────────────────────────────

class _ClipboardBanner extends StatefulWidget {
  final ClipboardItem item;
  final VoidCallback onSend;
  final VoidCallback? onDismiss;

  const _ClipboardBanner({
    required this.item,
    required this.onSend,
    this.onDismiss,
  });

  @override
  State<_ClipboardBanner> createState() => _ClipboardBannerState();
}

class _ClipboardBannerState extends State<_ClipboardBanner> {
  int? _fileSizeBytes;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void didUpdateWidget(_ClipboardBanner old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) {
      _loadSize();
    }
  }

  Future<void> _loadSize() async {
    final s = await widget.item.totalSize;
    if (mounted) {
      setState(() => _fileSizeBytes = s);
    }
  }

  // ─── icon per type / extension ────────────────────────────────────────────

  IconData get _icon {
    if (widget.item.type == ClipboardItemType.image) {
      return Icons.image_rounded;
    }
    if (widget.item.type == ClipboardItemType.text) {
      return Icons.text_snippet_rounded;
    }
    switch (widget.item.extensionHint) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file_rounded;
      case 'apk':
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  // ─── colour per type ──────────────────────────────────────────────────────

  Color get _color {
    if (widget.item.type == ClipboardItemType.image) {
      return const Color(0xFF007AFF); // أزرق — صورة
    }
    if (widget.item.type == ClipboardItemType.text) {
      return const Color(0xFF30B0C7); // تيل — نص
    }
    switch (widget.item.extensionHint) {
      case 'pdf':
        return const Color(0xFFFF3B30);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFFF9500);
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return const Color(0xFF5856D6);
      case 'mp3':
      case 'wav':
      case 'aac':
        return const Color(0xFFFF2D55);
      default:
        return const Color(0xFF34C759);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _typeLabel {
    final l10n = AppLocalizations.of(context);
    if (widget.item.type == ClipboardItemType.image) {
      return l10n.clipboardTypeImage;
    }
    if (widget.item.type == ClipboardItemType.text) {
      return l10n.clipboardTypeText;
    }
    if (widget.item.paths.length > 1) {
      return l10n.clipboardFileCount(widget.item.paths.length);
    }
    return widget.item.extensionHint.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final color = _color;

    return GestureDetector(
      onTap: widget.onSend,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          ),
        ),
        child: Row(
          children: [
            // ─── أيقونة النوع ────────────────────────────────────────────
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),

            // ─── اسم الملف + النوع + الحجم ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // السطر الأول: أيقونة الحافظة الصغيرة + اسم الملف
                  Row(
                    children: [
                      Icon(
                        Icons.content_paste_rounded,
                        size: 11,
                        color: color.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          clipboardLabel(
                              AppLocalizations.of(context), widget.item,
                              typeShown: true),
                          maxLines: widget.item.type == ClipboardItemType.text
                              ? 2
                              : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.item.type == ClipboardItemType.text
                                ? 12
                                : 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // السطر الثاني: نوع الملف + الحجم (الحجم مخفي للنص)
                  Row(
                    children: [
                      _TypeChip(label: _typeLabel, color: color),
                      if (_fileSizeBytes != null &&
                          widget.item.type != ClipboardItemType.text) ...[
                        const SizedBox(width: 6),
                        Text(
                          _formatSize(_fileSizeBytes!),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ─── زر الإرسال ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.4 : 0.3),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.send_rounded, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  l10n.clipboardSend,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 6),

            // ─── زر الإغلاق ──────────────────────────────────────────────
            GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Type Chip ────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// What the opened card head's menu does.
enum _HeadAction { share, pin, block }
