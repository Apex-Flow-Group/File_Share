import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/apex_core.dart';
import '../features/chat/logic/chat_key.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/device.dart';
import 'apex_colors.dart';
import 'apex_icons.dart';
import 'device_look.dart';
import 'framed_capsule_input.dart' show CapsuleAction;

/// One opened card at a time: opening another folds it (owner decision).
final _openCard = ValueNotifier<ChatKey?>(null);

@visibleForTesting
void foldDeviceCards() => _openCard.value = null;

/// Opens the card of the device with [key], folding any other.
void openDeviceCard(ChatKey key) => _openCard.value = key;

void foldDeviceCard(ChatKey key) {
  if (_openCard.value == key) {
    _openCard.value = null;
  }
}

/// An item of the opened card's ⋮ menu. [danger] items come last, apart.
typedef DeviceMenuEntry = ({
  IconData icon,
  String label,
  VoidCallback onTap,
  bool danger,
});

/// A device's card on the phone, the computer and the TV, one file for all
/// (owner decision): folded, a row like a messaging app's contact; touched,
/// or OK on the remote, it grows in place under that same row. What each
/// platform sends with, and how it picks, the host gives: the card draws.
List<DeviceMenuEntry> _noMenu() => const [];

class DeviceCard extends StatefulWidget {
  const DeviceCard({
    required this.device,
    this.usable = true,
    this.chat = false,
    this.status,
    this.rowActions = const [],
    this.actions = const [],
    this.menu = _noMenu,
    this.below = const [],
    this.body,
    this.remote = false,
    this.autofocus = false,
    this.focusNode,
    this.onBackToSidebar,
    super.key,
  });

  final Device device;

  /// Reachable and on this version; dimmed otherwise.
  final bool usable;

  /// A network device: the card is its chat, and folded it counts what is
  /// new, never the text, which may be a password read by anyone looking.
  final bool chat;

  /// Said in place of the address (offline, another version).
  final String? status;

  /// Circles of the folded row (paste and add on the phone).
  final List<CapsuleAction> rowActions;

  /// The opened card's first row: sends at once, where there is no message
  /// box (the TV, a Nearby-only phone).
  final List<CapsuleAction> actions;

  /// Built when the head is, so it follows a block made meanwhile.
  final List<DeviceMenuEntry> Function() menu;

  /// Under the head in both states: what is waiting to be sent, a send
  /// under way.
  final List<Widget> below;

  /// The rest of the opened card: the chat.
  final WidgetBuilder? body;

  /// The TV: everything by the remote, the card holds the focus.
  final bool remote;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onBackToSidebar;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: Durations.medium2,
    value: _expanded ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
      parent: _grow,
      curve: Easing.standard,
      reverseCurve: Easing.standard.flipped);

  /// Holds the card: the remote's focus on the TV; elsewhere only to know
  /// whether its message box is being written in, for back.
  late final FocusNode _focus = widget.focusNode ??
      FocusNode(
          skipTraversal: !widget.remote, canRequestFocus: widget.remote);
  final _firstAction = FocusNode();
  final _menuFocus = FocusNode();
  final _menuKey = GlobalKey<PopupMenuButtonState<DeviceMenuEntry>>();

  /// Where the remote goes in the opened card: its first send, or its menu
  /// where it has nothing to send (offline, the favourite still in reach).
  FocusNode? get _inside => _firstAction.context != null
      ? _firstAction
      : (_menuFocus.context != null ? _menuFocus : null);

  /// Whether the head's menu is open: its ⋮ shows ✕ then (capsule-ui §4).
  bool _menuOpen = false;

  bool get _expanded => _openCard.value == widget.device.chatKey;

  @override
  void initState() {
    super.initState();
    _openCard.addListener(_sync);
    // Folded all the way: the chat leaves the tree, not just the sight.
    _grow.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _openCard.removeListener(_sync);
    _curve.dispose();
    _grow.dispose();
    if (widget.focusNode == null) {
      _focus.dispose();
    }
    _firstAction.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    final open = _expanded;
    if (open == (_grow.status == AnimationStatus.forward ||
        _grow.status == AnimationStatus.completed)) {
      return;
    }
    final hadFocus = _focus.hasFocus;
    setState(() {});
    if (open) {
      _grow.forward();
      if (widget.remote) {
        // To the first thing to do in it, as a dialog would.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _inside?.requestFocus();
          }
        });
      }
    } else {
      _grow.reverse();
      if (widget.remote && hadFocus) {
        _focus.requestFocus();
      }
    }
  }

  void _toggle() => _expanded
      ? foldDeviceCard(widget.device.chatKey)
      : openDeviceCard(widget.device.chatKey);

  /// Back, one step at a time (owner decision): the system closes the
  /// keyboard, then the box is left, then the card folds. The remote has no
  /// box, so back folds and the focus stays on the card.
  void _back(bool didPop, Object? _) {
    if (didPop) {
      return;
    }
    if (!widget.remote && _focus.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    foldDeviceCard(widget.device.chatKey);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    // A button inside takes its own OK; the card only when it is the focus.
    if (event is! KeyDownEvent || !_focus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
      _toggle();
      return KeyEventResult.handled;
    }
    final inside = _inside;
    if (key == LogicalKeyboardKey.arrowDown && _expanded && inside != null) {
      inside.requestFocus();
      return KeyEventResult.handled;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (key == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      widget.onBackToSidebar?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
    final expanded = _expanded;
    Widget card = Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      onKeyEvent: widget.remote ? _key : null,
      child: Builder(builder: (context) {
        final ring = widget.remote && Focus.of(context).hasPrimaryFocus;
        return AnimatedContainer(
          duration: Durations.short2,
          curve: Easing.standard,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.panel,
            borderRadius: BorderRadius.circular(20),
            // The remote's place is a ring in the accent; otherwise the
            // panel's own border, as the sidebar.
            border: Border.all(
                color: ring ? c.accent : c.panelBorder, width: ring ? 2.5 : 1),
          ),
          child: Opacity(
            opacity: widget.usable ? 1 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _head(context, c, expanded),
                if (widget.below.isNotEmpty) const SizedBox(height: 12),
                ...widget.below,
                // One movement: the card grows under its head and shrinks
                // back, the content sliding with it, never fading.
                SizeTransition(
                  sizeFactor: _curve,
                  axisAlignment: -1,
                  child: _grow.isDismissed && !expanded
                      ? const SizedBox(width: double.infinity)
                      : _opened(context),
                ),
              ],
            ),
          ),
        );
      }),
    );
    if (expanded) {
      card = PopScope(canPop: false, onPopInvokedWithResult: _back, child: card);
    }
    return card;
  }

  Widget _opened(BuildContext context) {
    final body = widget.body;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.actions.isNotEmpty) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (i, a) in widget.actions.indexed)
                _Circle(action: a, labeled: true, focusNode: i == 0 ? _firstAction : null),
            ]),
            if (body != null) const SizedBox(height: 14),
          ],
          if (body != null) body(context),
        ],
      ),
    );
  }

  Widget _head(BuildContext context, ApexColors c, bool expanded) {
    final l10n = AppLocalizations.of(context);
    final device = widget.device;
    final store = ApexCore.instance.chat;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final unread = widget.chat ? store.unread(device.chatKey) : 0;
        final Widget second;
        if (widget.status != null) {
          second = Text(widget.status!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.muted));
        } else if (!expanded && unread > 0) {
          second = Text(l10n.chatUnread(unread),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: c.accent));
        } else {
          second = Row(children: [
            if (expanded) ...[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: _TransportBadge(device: device),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (!device.isNearby && device.ip.isNotEmpty)
              Flexible(
                child: Text(device.ip,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.muted)),
              )
            else if (!expanded)
              Text(l10n.directConnection,
                  style: TextStyle(fontSize: 12, color: c.muted)),
          ]);
        }
        final color = deviceColor(device);
        final row = Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(deviceIcon(device), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The online dot before the name, over the network badge
                // (owner decision), not among the buttons.
                Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.usable ? c.online : c.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: c.text)),
                  ),
                ]),
                const SizedBox(height: 3),
                second,
              ],
            ),
          ),
          if (expanded)
            _headCapsule(l10n, c)
          else if (widget.usable &&
              !(widget.chat && store.isBlocked(device.chatPeer)))
            // Blocked: nothing goes to or comes from it.
            for (final (i, a) in widget.rowActions.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              _Circle(action: a),
            ],
        ]);
        return Semantics(
          button: true,
          label: expanded
              ? (widget.chat ? l10n.chatClose : l10n.cardFold)
              : (widget.chat ? l10n.chatOpen : l10n.deviceOptions),
          // The remote opens it from the card itself; a touch on the head.
          child: widget.remote
              ? row
              : InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _toggle,
                  child: row,
                ),
        );
      },
    );
  }

  /// The menu and the fold arrow side by side are one filled capsule
  /// (capsule-ui §1), a step lighter than the card, no border and no glow
  /// on a card.
  Widget _headCapsule(AppLocalizations l10n, ApexColors c) {
    return Container(
      height: 48,
      decoration:
          BoxDecoration(color: c.circle, borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.menu().isNotEmpty) _headMenu(l10n, c),
        Tooltip(
          message: widget.chat ? l10n.chatClose : l10n.cardFold,
          excludeFromSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            focusColor: c.accent.withValues(alpha: 0.35),
            onTap: _toggle,
            child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(ApexIcons.fold, color: c.onCircle)),
          ),
        ),
      ]),
    );
  }

  void _menuShut() {
    if (mounted) {
      setState(() => _menuOpen = false);
    }
  }

  Widget _headMenu(AppLocalizations l10n, ApexColors c) {
    return PopupMenuButton<DeviceMenuEntry>(
      key: _menuKey,
      // Its own button below opens it, with a focus the remote can reach:
      // this one has none to give.
      enabled: false,
      tooltip: '',
      color: c.circle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onOpened: () => setState(() => _menuOpen = true),
      onCanceled: _menuShut,
      onSelected: (m) {
        _menuShut();
        m.onTap();
      },
      itemBuilder: (context) {
        final all = widget.menu();
        final plain = [for (final m in all) if (!m.danger) m];
        final danger = [for (final m in all) if (m.danger) m];
        return [
          for (final m in plain) _item(m, c, c.onCircle),
          if (plain.isNotEmpty && danger.isNotEmpty) const PopupMenuDivider(),
          for (final m in danger) _item(m, c, c.danger),
        ];
      },
      // ⋮ in a narrower button, so the capsule stays small (capsule-ui §3).
      child: Tooltip(
        message: l10n.deviceOptions,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: l10n.deviceOptions,
          child: InkWell(
            focusNode: _menuFocus,
            customBorder: const StadiumBorder(),
            focusColor: c.accent.withValues(alpha: 0.35),
            onTap: () => _menuKey.currentState?.showButtonMenu(),
            child: SizedBox(
              width: 40,
              height: 48,
              child: Icon(_menuOpen ? ApexIcons.close : ApexIcons.menu,
                  color: c.onCircle),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<DeviceMenuEntry> _item(
          DeviceMenuEntry m, ApexColors c, Color color) =>
      PopupMenuItem(
        value: m,
        // A plain row, not a ListTile: its own focus would be a second stop
        // for the remote on the same item, one that does nothing.
        child: Row(children: [
          Icon(m.icon, color: color),
          const SizedBox(width: 16),
          Flexible(child: Text(m.label, style: TextStyle(color: color))),
        ]),
      );
}

/// A circle of the card, a step lighter than the panel, 48 to touch.
/// [labeled] puts its name beside it, where it sends at once: a lone icon
/// does not say what it sends.
class _Circle extends StatelessWidget {
  const _Circle({required this.action, this.labeled = false, this.focusNode});

  final CapsuleAction action;
  final bool labeled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
    final icon = Icon(action.icon, color: c.onCircle, size: 22);
    return Tooltip(
      message: action.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: action.label,
        excludeSemantics: true,
        child: Material(
          color: c.circle,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: focusNode,
            onTap: action.onTap,
            // The remote's place on a circle: the accent around it.
            focusColor: c.accent.withValues(alpha: 0.35),
            child: labeled
                ? Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 18, 0),
                    child: SizedBox(
                      height: 48,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        icon,
                        const SizedBox(width: 8),
                        Text(action.label,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: c.onCircle)),
                      ]),
                    ),
                  )
                : SizedBox.square(dimension: 48, child: icon),
          ),
        ),
      ),
    );
  }
}

/// How the device is reached: the network, or directly (Nearby).
class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (device.isNearby) _badge(context, ApexIcons.direct, l10n.directConnection),
      if (device.isNearby && device.isMdns) const SizedBox(width: 4),
      if (device.isMdns || !device.isNearby) _badge(context, ApexIcons.network, 'WiFi'),
    ]);
  }

  Widget _badge(BuildContext context, IconData icon, String label) {
    final c = ApexColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.circle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c.onCircle),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: c.onCircle, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// A line under the head that says why nothing can be done now: another
/// version, a send to another device.
class DeviceCardNote extends StatelessWidget {
  const DeviceCardNote({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = ApexColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.hover,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: c.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: c.text, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
