import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/platform_detector.dart';
import 'apex_colors.dart';
import 'apex_icons.dart';

/// A plain circle of the box's button row.
typedef CapsuleAction = ({IconData icon, String label, VoidCallback onTap});

/// A message box as in chat apps (owner's reference): what is attached on
/// top, the text across the whole box, and a row of buttons under it, the
/// clip and paste at the start and send at the end. On a computer Enter
/// sends and Shift+Enter starts a new line.
class FramedCapsuleInput extends StatefulWidget {
  const FramedCapsuleInput({
    required this.hint,
    required this.sendLabel,
    required this.onSend,
    this.hasAttachments = false,
    this.onAttach,
    this.attachLabel,
    this.autofocus = false,
    this.initialText,
    this.pasteLabel,
    this.onPasteEmpty,
    this.top,
    this.controller,
    this.extras = const [],
    super.key,
  });

  final String hint;

  /// Read by screen readers for the send circle, which has no text.
  final String sendLabel;

  /// False keeps the text in the box (the caller said why).
  final bool Function(String text) onSend;

  /// Something is attached, so send works with no text too.
  final bool hasAttachments;

  /// The clip; none when null (the TV).
  final VoidCallback? onAttach;
  final String? attachLabel;

  final bool autofocus;

  /// Text already in the box when it opens (a paste from the card).
  final String? initialText;

  /// Shows a paste circle after the clip. The clipboard is read only when
  /// the user presses it (owner decision), and the text goes in the box,
  /// never straight out.
  final String? pasteLabel;
  final VoidCallback? onPasteEmpty;

  /// Above the text, inside the box: the attached files.
  final Widget? top;

  /// Given by a caller that puts text in the box itself (a copied text).
  final TextEditingController? controller;

  /// More plain circles after paste, each doing its own thing at once
  /// (send a folder, send an app).
  final List<CapsuleAction> extras;

  @override
  State<FramedCapsuleInput> createState() => _FramedCapsuleInputState();
}

class _FramedCapsuleInputState extends State<FramedCapsuleInput> {
  static const _circle = 40.0;
  static const _touch = 48.0;

  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  static bool get _desktop => PlatformDetector.instance.isDesktop;

  bool get _canSend => widget.hasAttachments || _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null) {
      _controller.text = initial;
      _controller.selection = TextSelection.collapsed(offset: initial.length);
    }
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty) {
      widget.onPasteEmpty?.call();
      return;
    }
    final v = _controller.value;
    final start = v.selection.isValid ? v.selection.start : v.text.length;
    final end = v.selection.isValid ? v.selection.end : v.text.length;
    _controller.value = TextEditingValue(
      text: v.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _focus.requestFocus();
  }

  void _send() {
    if (!_canSend) {
      return;
    }
    if (widget.onSend(_controller.text)) {
      _controller.clear();
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
    Widget field = TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      minLines: 1,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: TextStyle(color: c.text, fontSize: 16),
      cursorColor: c.text,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintMaxLines: 1,
        hintStyle: TextStyle(color: c.hint, fontSize: 16),
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
    if (_desktop) {
      field = CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
        child: field,
      );
    }
    final top = widget.top;
    final buttons = [
      if (widget.onAttach != null)
        _circleButton(
          label: widget.attachLabel ?? '',
          enabled: true,
          onTap: widget.onAttach!,
          background: c.circle,
          icon: ApexIcons.attach,
          iconColor: c.onCircle,
        ),
      if (widget.pasteLabel != null)
        _circleButton(
          label: widget.pasteLabel!,
          enabled: true,
          onTap: _paste,
          background: c.circle,
          icon: ApexIcons.paste,
          iconColor: c.onCircle,
        ),
      for (final x in widget.extras)
        _circleButton(
          label: x.label,
          enabled: true,
          onTap: x.onTap,
          background: c.circle,
          icon: x.icon,
          iconColor: c.onCircle,
        ),
    ];
    final send = _circleButton(
      label: widget.sendLabel,
      enabled: _canSend,
      onTap: _send,
      background: c.filled,
      icon: ApexIcons.send,
      iconColor: c.onFilled,
    );
    // The text above the buttons from the start (owner decision): beside
    // three circles on a phone the hint was left two lines.
    return Container(
      decoration: BoxDecoration(
        color: c.capsule,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.capsuleBorder),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (top != null) Padding(padding: const EdgeInsets.all(4), child: top),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: field),
          Row(children: [...buttons, const Spacer(), send]),
        ],
      ),
    );
  }

  /// One circle of the box, all of the same size; under 48dp, so the touch
  /// area reaches past it.
  Widget _circleButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required Color background,
    required IconData icon,
    required Color iconColor,
  }) =>
      Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onTap : null,
            child: SizedBox.square(
              dimension: _touch,
              child: Center(
                child: AnimatedOpacity(
                  opacity: enabled ? 1 : 0.4,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: _circle,
                    height: _circle,
                    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
