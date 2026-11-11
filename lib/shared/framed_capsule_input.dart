import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/platform_detector.dart';

/// Colour roles of the framed capsule (capsule-ui §1b). Dark is measured from
/// the owner's reference; light follows the same steps and is not approved yet.
class FramedCapsuleColors {
  const FramedCapsuleColors._({
    required this.capsule,
    required this.border,
    required this.filled,
    required this.onFilled,
    required this.hint,
    required this.text,
    required this.circle,
    required this.onCircle,
  });

  final Color capsule;
  final Color border;

  /// The one filled circle, the first action: the background's opposite.
  final Color filled;
  final Color onFilled;
  final Color hint;
  final Color text;

  /// The other circles: one small step lighter than the capsule.
  final Color circle;
  final Color onCircle;

  static const _dark = FramedCapsuleColors._(
    capsule: Color(0xFF20201E),
    border: Color(0xFF3C3C3A),
    filled: Color(0xFFF9F9F7),
    onFilled: Color(0xFF1F1F1D),
    hint: Color(0xFF9A9792),
    text: Color(0xFFF4F4F2),
    circle: Color(0xFF313131),
    onCircle: Color(0xFFF4F4F2),
  );

  static const _light = FramedCapsuleColors._(
    capsule: Color(0xFFF1F1EF),
    border: Color(0xFFCFCFCB),
    filled: Color(0xFF1F1F1D),
    onFilled: Color(0xFFF9F9F7),
    hint: Color(0xFF66645F),
    text: Color(0xFF1F1F1D),
    circle: Color(0xFFE2E2DF),
    onCircle: Color(0xFF1F1F1D),
  );

  static FramedCapsuleColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// A writing line: one line while empty, growing upward as the text grows,
/// with the send circle staying at the bottom. On a computer Enter sends and
/// Shift+Enter starts a new line.
class FramedCapsuleInput extends StatefulWidget {
  const FramedCapsuleInput({
    required this.hint,
    required this.sendLabel,
    required this.onSend,
    this.onAttach,
    this.attachLabel,
    this.onOpen,
    this.autofocus = false,
    super.key,
  });

  final String hint;

  /// Read by screen readers for the send circle, which has no text.
  final String sendLabel;

  /// False keeps the text in the line (the caller said why).
  final bool Function(String text) onSend;

  /// A plain circle before the send one; none when null (the TV).
  final VoidCallback? onAttach;
  final String? attachLabel;

  /// Set on a device card: the line only leads to the chat. Touching it
  /// opens the chat, where the writing happens and the replies are.
  final VoidCallback? onOpen;
  final bool autofocus;

  @override
  State<FramedCapsuleInput> createState() => _FramedCapsuleInputState();
}

class _FramedCapsuleInputState extends State<FramedCapsuleInput> {
  /// Capsule height while one line; the circle is ~69% of it, the margin ~15%.
  static const _height = 56.0;
  static const _circle = 38.0;
  static const _margin = (_height - _circle) / 2;
  static const _touch = 48.0;
  static const _touchExtra = (_touch - _circle) / 2;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  static bool get _desktop => PlatformDetector.instance.isDesktop;

  bool get _canSend => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
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
    final c = FramedCapsuleColors.of(context);
    if (widget.onOpen != null) {
      return _capsule(
        c,
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(widget.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.hint, fontSize: 16)),
            ),
          ),
        ),
      );
    }
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
        hintStyle: TextStyle(color: c.hint, fontSize: 16),
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
    if (_desktop) {
      field = CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
        child: field,
      );
    }
    return _capsule(c, field);
  }

  Widget _capsule(FramedCapsuleColors c, Widget field) => Container(
        constraints: const BoxConstraints(minHeight: _height),
        decoration: BoxDecoration(
          color: c.capsule,
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(color: c.border),
        ),
        padding: EdgeInsetsDirectional.only(
            start: widget.onAttach != null ? _margin - _touchExtra : 20, end: _margin - _touchExtra),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // At the start, as in the owner's reference; send stays at the end.
            if (widget.onAttach != null) ...[
              _circleButton(
                label: widget.attachLabel ?? '',
                enabled: true,
                onTap: widget.onAttach!,
                background: c.circle,
                icon: Icons.attach_file_rounded,
                iconColor: c.onCircle,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: field),
            const SizedBox(width: 4),
            // On a card it leads to the chat too, instead of sitting dim.
            _circleButton(
              label: widget.sendLabel,
              enabled: widget.onOpen != null || _canSend,
              onTap: widget.onOpen ?? _send,
              background: c.filled,
              icon: Icons.arrow_upward_rounded,
              iconColor: c.onFilled,
            ),
          ],
        ),
      );

  /// One circle of the line, all of the same size; under 48dp, so the touch
  /// area reaches past it.
  Widget _circleButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required Color background,
    required IconData icon,
    required Color iconColor,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: _margin - _touchExtra),
        child: Tooltip(
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
        ),
      );
}
