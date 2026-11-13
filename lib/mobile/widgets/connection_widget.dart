import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show BidiFormatter;

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
import '../../shared/apex_colors.dart';
import '../../shared/apex_icons.dart';
import '../../shared/apex_snackbar.dart';
import '../../shared/device_card.dart';
import '../../shared/framed_capsule_input.dart' show CapsuleAction;
import '../../utils/path_name.dart';
import '../screens/share_browser_screen.dart';
import 'chat_card_parts.dart';
import 'connection_send_actions.dart';
import 'transfer_progress_indicator.dart';

enum _Status { idle, sending }

/// A device's card on the phone and the computer: the shared [DeviceCard]
/// with what these send with (the file picker, the message box).
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = widget.device;
    // Another version is listed but nothing is sent to it.
    final usable = widget.isActive && !device.versionMismatch;
    // A network device is a chat (owner decision); a Nearby-only phone has
    // no message box, so it sends at once from the opened card.
    final chat = usable && device.isMdns;
    final otherBusy = widget.isGloballyBusy &&
        _status == _Status.idle &&
        TransferProgressService().targetDeviceId != device.id;
    final copied = _status != _Status.idle || widget.isGloballyBusy
        ? null
        : widget.pendingClipboardItem;
    return DeviceCard(
      device: device,
      usable: usable,
      chat: chat,
      // Offline first, as on the TV: it is what the device is now.
      status: widget.isActive ? null : l10n.deviceOffline,
      rowActions: chat
          ? [
              (icon: ApexIcons.paste, label: l10n.chatPaste, onTap: _pasteFromRow),
              (icon: ApexIcons.attach, label: l10n.chatAttach, onTap: _attachFromRow),
            ]
          : const [],
      actions: usable && !chat && !otherBusy && _status == _Status.idle
          ? [
              (icon: ApexIcons.sendFilesNow, label: l10n.sendFilesNow, onTap: sendFile),
              _appOrFolder(l10n),
            ]
          : const [],
      menu: () => _menu(l10n, usable, chat),
      below: [
        ..._banners(l10n, usable, withClipboard: !chat),
        if (widget.isActive && device.versionMismatch)
          DeviceCardNote(icon: ApexIcons.versionDiffers, text: l10n.updateRequired),
        if (_status == _Status.sending) _buildSendingState(),
      ],
      body: !usable
          ? null
          : (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (otherBusy) _buildBusyBar(l10n),
                  if (otherBusy && chat) const SizedBox(height: 10),
                  if (chat)
                    ChatCardPanel(
                      key: ValueKey(_pasteSeq),
                      device: device,
                      initialText: _paste,
                      initialFiles: _picked,
                      copied: copied,
                      onCopiedUsed: _copiedUsed,
                      // Sends at once from the box's row, after the clip and
                      // paste (owner decision); not while another send runs,
                      // one at a time as the box's own files.
                      extras: widget.isGloballyBusy || _status != _Status.idle
                          ? const []
                          : [_appOrFolder(l10n)],
                    ),
                ],
              ),
    );
  }

  /// An app on a phone, a folder elsewhere.
  CapsuleAction _appOrFolder(AppLocalizations l10n) => Platform.isAndroid
      ? (icon: ApexIcons.sendApp, label: l10n.sendApp, onTap: sendApp)
      : (icon: ApexIcons.sendFolder, label: l10n.sendFolder, onTap: sendFolder);

  /// The shared folder and the favourite, then block last, apart and red
  /// (owner decision): three buttons in the head left the name a few letters
  /// wide.
  List<DeviceMenuEntry> _menu(AppLocalizations l10n, bool usable, bool chat) {
    final store = ApexCore.instance.chat;
    final pin = widget.isPinned ? widget.onUnpin : widget.onPin;
    return [
      if (usable && widget.device.hasShare)
        (icon: ApexIcons.sharedFolder, label: l10n.sharedFolder, onTap: _openShareBrowser, danger: false),
      if (pin != null)
        (
          icon: widget.isPinned ? ApexIcons.unfavorite : ApexIcons.favorite,
          label: widget.isPinned ? l10n.unpinDevice : l10n.pinDevice,
          onTap: pin,
          danger: false,
        ),
      if (chat && store.canBlock(widget.device.chatPeer))
        (icon: ApexIcons.block, label: l10n.chatBlock, onTap: _block, danger: true),
    ];
  }

  Future<void> _block() async {
    if (await confirmBlock(context, widget.device.name)) {
      ApexCore.instance.chat.block(widget.device.chatPeer);
    }
  }

  /// [withClipboard] false on a chat card: what was copied shows inside the
  /// message box there (owner decision).
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

  /// What the card's paste took from the clipboard, for the message box.
  String? _paste;

  /// What the row's clip picked, for the message box.
  List<String> _picked = const [];

  /// A new paste or pick rebuilds the message box with it.
  int _pasteSeq = 0;

  void _open({String? paste, List<String> picked = const []}) {
    setState(() {
      _paste = paste;
      _picked = picked;
      _pasteSeq++;
    });
    openDeviceCard(widget.device.chatKey);
  }

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

  /// Something waiting to be sent to this device, sent with a touch.
  Widget _sendBanner(IconData icon, String text, VoidCallback onTap) {
    final c = ApexColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.hover,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, color: c.muted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: TextStyle(color: c.text, fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(ApexIcons.send, color: c.text, size: 16),
            ]),
          ),
        ),
      ),
    );
  }

  /// A Latin file name inside an Arabic line would turn the line around: it
  /// is isolated in its own direction.
  String _isolated(String name) => BidiFormatter.UNKNOWN().wrapWithUnicode(name);

  Widget _buildPendingFileBanner(AppLocalizations l10n) {
    final fileName = fileNameOf(widget.pendingFilePath!);
    return _sendBanner(Icons.note_rounded, l10n.sendPending(_isolated(fileName)), _sendPendingFile);
  }

  Widget _buildSharedFilesBanner(AppLocalizations l10n) {
    final files = widget.pendingSharedFiles!;
    final label = files.length == 1
        ? _isolated(fileNameOf(files.first))
        : l10n.clipboardFileCount(files.length);
    return _sendBanner(Icons.share_rounded, l10n.sendPending(label), _sendSharedFiles);
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
    final l10n = AppLocalizations.of(context);
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
          : l10n.clipboardFileCount(paths.length);
      await DesktopNotificationService.instance
          .showSendResult(outcome, label);
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
      await DesktopNotificationService.instance
          .showSendResult(outcome, label);
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setIdle();
      }
    }
  }

  void _openShareBrowser() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareBrowserScreen(device: widget.device),
      ),
    );
  }

  /// The words the message box says for the same wait, and the TV card.
  Widget _buildBusyBar(AppLocalizations l10n) =>
      DeviceCardNote(icon: ApexIcons.busy, text: l10n.chatTransferBusy);

  Widget _buildSendingState() {
    return TransferProgressIndicator(
      onCancel: () {
        _cancelledByUser = true;
        TransferProgressService().cancelTransfer();
        setState(() => _status = _Status.idle);
      },
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
                        ApexIcons.paste,
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
                Icon(ApexIcons.send, size: 13, color: color),
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
            Semantics(
              button: true,
              label: AppLocalizations.of(context).dismiss,
              child: GestureDetector(
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

