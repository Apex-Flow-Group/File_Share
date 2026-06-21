import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/apex_core.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../../screens/apps_selection_screen.dart';
import '../../services/desktop_notification_service.dart';
import '../../services/transfer_progress_service.dart';
import '../connection_widget.dart';
import '../tv_file_browser.dart';

class TVSendTab extends StatefulWidget {
  final List<Device> devices;
  final bool isRunning;
  final VoidCallback? onBackToSidebar;
  final FocusNode? contentFocusNode;
  const TVSendTab({
    required this.devices,
    required this.isRunning,
    this.onBackToSidebar,
    this.contentFocusNode,
    super.key,
  });

  @override
  State<TVSendTab> createState() => _TVSendTabState();
}

class _TVSendTabState extends State<TVSendTab> with TickerProviderStateMixin {
  late AnimationController _radarSpin;
  late AnimationController _pulseFast;
  late AnimationController _pulseSlow;

  @override
  void initState() {
    super.initState();
    _radarSpin =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _pulseFast = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseSlow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarSpin.dispose();
    _pulseFast.dispose();
    _pulseSlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: widget.devices.isEmpty ? _buildScanning() : _buildDeviceList(),
    );
  }

  Widget _buildScanning() {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      _buildHeader(l10n),
      Expanded(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedBuilder(
                  animation: _pulseSlow,
                  builder: (_, __) => Container(
                    width: 180 + _pulseSlow.value * 40,
                    height: 180 + _pulseSlow.value * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(
                            alpha: 0.15 - _pulseSlow.value * 0.12),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseFast,
                  builder: (_, __) => Container(
                    width: 130 + _pulseFast.value * 30,
                    height: 130 + _pulseFast.value * 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(
                            alpha: 0.25 - _pulseFast.value * 0.2),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                  ),
                ),
                if (widget.isRunning)
                  AnimatedBuilder(
                    animation: _radarSpin,
                    builder: (_, __) => Transform.rotate(
                      angle: _radarSpin.value * 2 * pi,
                      child: CustomPaint(
                        size: const Size(100, 100),
                        painter: _RadarSweepPainter(color),
                      ),
                    ),
                  ),
                Icon(
                  widget.isRunning
                      ? Icons.wifi_tethering_rounded
                      : Icons.wifi_tethering_off_rounded,
                  size: 42,
                  color: color,
                ),
              ]),
            ),
            const SizedBox(height: 28),
            Text(
              widget.isRunning ? l10n.discovering : l10n.noDevicesFound,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.makeSureDevicesOnSameNetwork,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildDeviceList() {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(l10n),
      Expanded(
        child: StreamBuilder<dynamic>(
          stream: TransferProgressService().progressStream,
          builder: (context, snapshot) {
            final svc = TransferProgressService();
            final isTransferring = svc.isTransferring;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: widget.devices.length,
              itemBuilder: (context, i) {
                final device = widget.devices[i];
                final isTarget =
                    isTransferring && svc.targetDeviceId == device.id;
                return _TVDeviceCard(
                  device: device,
                  isGloballyBusy: isTransferring && !isTarget,
                  autofocus: i == 0,
                  contentFocusNode: i == 0 ? widget.contentFocusNode : null,
                  onBackToSidebar: widget.onBackToSidebar,
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]
              : [color.withValues(alpha: 0.12), color.withValues(alpha: 0.03)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.send_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.send,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              '${widget.devices.length} ${l10n.availableDevices}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ]),
        ),
        if (widget.isRunning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('Live',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}

// ─── TV Device Card ───────────────────────────────────────────────────────────

class _TVDeviceCard extends StatefulWidget {
  final Device device;
  final bool isGloballyBusy;
  final bool autofocus;
  final FocusNode? contentFocusNode;
  final VoidCallback? onBackToSidebar;
  const _TVDeviceCard({
    required this.device,
    this.isGloballyBusy = false,
    this.autofocus = false,
    this.contentFocusNode,
    this.onBackToSidebar,
  });

  @override
  State<_TVDeviceCard> createState() => _TVDeviceCardState();
}

class _TVDeviceCardState extends State<_TVDeviceCard> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.contentFocusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.contentFocusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          _showSendOptions(context);
          return KeyEventResult.handled;
        }
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final toSidebarKey = isRtl
            ? LogicalKeyboardKey.arrowRight
            : LogicalKeyboardKey.arrowLeft;
        if (event.logicalKey == toSidebarKey) {
          widget.onBackToSidebar?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: hasFocus
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.2), blurRadius: 12)
                  ],
                )
              : null,
          child: ConnectionWidget(
            device: widget.device,
            isGloballyBusy: widget.isGloballyBusy,
          ),
        );
      }),
    );
  }

  void _showSendOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (dialogContext) => _TVOptionsDialog(
        title: widget.device.name,
        isDark: isDark,
        color: color,
        options: [
          _TVOption(
            icon: Icons.folder_open_rounded,
            label: l10n.sendFile,
            color: color,
            onTap: () {
              Navigator.pop(dialogContext);
              _sendFile();
            },
          ),
          _TVOption(
            icon: Icons.android_rounded,
            label: l10n.sendApp,
            color: const Color(0xFF34C759),
            onTap: () {
              Navigator.pop(dialogContext);
              _sendApp();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendFile() async {
    final paths = await showTVFileBrowser(context);
    if (paths == null || paths.isEmpty || !mounted) {
      return;
    }

    final ok = await ApexCore.instance.sendFiles(paths, widget.device);
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l10n.fileSentSuccess : l10n.fileSendFailed),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
    final label = paths.length == 1
        ? paths.first.split('/').last
        : '${paths.length} files';
    if (ok) {
      await DesktopNotificationService.instance.showFileSent(label);
    } else {
      await DesktopNotificationService.instance.showSendFailed(label);
    }
    TransferProgressService().clearProgress();
  }

  Future<void> _sendApp() async {
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppsSelectionScreen(
          onAppSelected: (apkFile, appName) async {
            if (!mounted) {
              return;
            }
            final ok = await ApexCore.instance
                .sendFileWithName(apkFile.path, '$appName.apk', widget.device);
            if (!mounted) {
              return;
            }
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? l10n.appSent : l10n.sendFailed),
              backgroundColor: ok ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
            TransferProgressService().clearProgress();
          },
        ),
      ),
    );
  }
}

// ─── TV Options Dialog ────────────────────────────────────────────────────────
// Dialog مخصص للريموت — أسهل من BottomSheet في التنقل

class _TVOption {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _TVOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _TVOptionsDialog extends StatelessWidget {
  final String title;
  final bool isDark;
  final Color color;
  final List<_TVOption> options;

  const _TVOptionsDialog({
    required this.title,
    required this.isDark,
    required this.color,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ...options.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TVOptionButton(
                  option: opt,
                  autofocus: i == 0,
                  isDark: isDark,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TVOptionButton extends StatefulWidget {
  final _TVOption option;
  final bool autofocus;
  final bool isDark;

  const _TVOptionButton({
    required this.option,
    required this.autofocus,
    required this.isDark,
  });

  @override
  State<_TVOptionButton> createState() => _TVOptionButtonState();
}

class _TVOptionButtonState extends State<_TVOptionButton> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.option.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: widget.option.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasFocus
                  ? widget.option.color.withValues(alpha: 0.15)
                  : widget.option.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: hasFocus
                  ? Border.all(color: widget.option.color, width: 2)
                  : Border.all(
                      color: widget.option.color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(widget.option.icon, color: widget.option.color, size: 22),
              const SizedBox(width: 12),
              Text(widget.option.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.option.color,
                  )),
            ]),
          ),
        );
      }),
    );
  }
}

// ─── Radar Sweep Painter ─────────────────────────────────────────────────────

class _RadarSweepPainter extends CustomPainter {
  final Color color;
  _RadarSweepPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.5)],
        stops: const [0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
