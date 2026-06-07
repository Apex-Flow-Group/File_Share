import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/device.dart';
import '../connection_widget.dart';

class TVSendTab extends StatefulWidget {
  final List<Device> devices;
  final bool isRunning;
  const TVSendTab({required this.devices, required this.isRunning, super.key});

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
    _radarSpin = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseFast = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseSlow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
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
              width: 220, height: 220,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedBuilder(
                  animation: _pulseSlow,
                  builder: (_, __) => Container(
                    width: 180 + _pulseSlow.value * 40,
                    height: 180 + _pulseSlow.value * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.15 - _pulseSlow.value * 0.12),
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
                        color: color.withValues(alpha: 0.25 - _pulseFast.value * 0.2),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 100, height: 100,
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
                  widget.isRunning ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                  size: 42, color: color,
                ),
              ]),
            ),
            const SizedBox(height: 28),
            Text(
              widget.isRunning ? l10n.discovering : l10n.noDevicesFound,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          itemCount: widget.devices.length,
          itemBuilder: (context, i) => _TVDeviceCard(device: widget.devices[i]),
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.send,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('Live', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}

// ─── TV Device Card ───────────────────────────────────────────────────────────
// Same as ConnectionWidget but with TV-friendly focus border

class _TVDeviceCard extends StatefulWidget {
  final Device device;
  const _TVDeviceCard({required this.device});

  @override
  State<_TVDeviceCard> createState() => _TVDeviceCardState();
}

class _TVDeviceCardState extends State<_TVDeviceCard> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          _focusNode.requestFocus();
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
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12)],
                )
              : null,
          child: ConnectionWidget(device: widget.device),
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
