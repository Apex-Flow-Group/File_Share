import 'dart:math';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../services/clipboard_monitor_service.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../shared/radar_painter.dart';
import '../connection_widget.dart';

class SendTab extends StatefulWidget {
  final List<Device> devices;
  final List<Device> pinnedDevices;
  final bool isRunning;
  final String? pendingFilePath;
  final VoidCallback? onPendingFileSent;
  final List<String>? pendingSharedFiles;
  final VoidCallback? onSharedFilesSent;
  final ClipboardItem? pendingClipboardItem;
  final VoidCallback? onClipboardItemSent;
  final bool Function(String) isPinned;
  final Future<void> Function(Device) onPin;
  final Future<void> Function(String) onUnpin;

  const SendTab({
    required this.devices,
    required this.pinnedDevices,
    required this.isRunning,
    required this.isPinned,
    required this.onPin,
    required this.onUnpin,
    this.pendingFilePath,
    this.onPendingFileSent,
    this.pendingSharedFiles,
    this.onSharedFilesSent,
    this.pendingClipboardItem,
    this.onClipboardItemSent,
    super.key,
  });

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> with TickerProviderStateMixin {
  late AnimationController _radarSpin;
  late AnimationController _pulseFast;
  late AnimationController _pulseSlow;

  @override
  void initState() {
    super.initState();
    _radarSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseFast = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseSlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hasAny = widget.devices.isNotEmpty || widget.pinnedDevices.isNotEmpty;
    return SafeArea(
      bottom: false,
      child: !hasAny
          ? _buildScanning()
          : isDesktop
              ? _buildDesktopList()
              : _buildDeviceList(),
    );
  }

  // ─── Scanning Screen ───────────────────────────────────────────────────────

  Widget _buildScanning() {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildHeader(l10n),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseSlow,
                        builder: (_, __) => Container(
                          width: 160 + _pulseSlow.value * 40,
                          height: 160 + _pulseSlow.value * 40,
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
                          width: 120 + _pulseFast.value * 30,
                          height: 120 + _pulseFast.value * 30,
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
                        width: 90,
                        height: 90,
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
                              size: const Size(90, 90),
                              painter: RadarSweepPainter(color),
                            ),
                          ),
                        ),
                      Icon(
                        widget.isRunning
                            ? Icons.wifi_tethering_rounded
                            : Icons.wifi_tethering_off_rounded,
                        size: 36,
                        color: color,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.isRunning ? l10n.discovering : l10n.noDevicesFound,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.makeSureDevicesOnSameNetwork,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Desktop List (Pinned + New) ───────────────────────────────────────────

  Widget _buildDesktopList() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16;

    // الأجهزة الجديدة = المكتشفة وليست مثبتة
    final newDevices =
        widget.devices.where((d) => !widget.isPinned(d.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(l10n),
        Expanded(
          child: StreamBuilder<dynamic>(
            stream: TransferProgressService().progressStream,
            builder: (context, snapshot) {
              final svc = TransferProgressService();
              final isTransferring = svc.isTransferring;
              return ListView(
                physics: isTransferring
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                children: [
                  // ─── الأجهزة المثبتة
                  if (widget.pinnedDevices.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.push_pin_rounded,
                      label: l10n.pinnedDevices,
                      isDark: isDark,
                    ),
                    ...widget.pinnedDevices.map((pinned) {
                      final active = widget.devices
                          .where((d) => d.id == pinned.id)
                          .firstOrNull;
                      return ConnectionWidget(
                        device: active ?? pinned,
                        isActive: active != null,
                        isPinned: true,
                        onPin: () => widget.onPin(active ?? pinned),
                        onUnpin: () => widget.onUnpin(pinned.id),
                        pendingFilePath: widget.pendingFilePath,
                        onPendingFileSent: widget.onPendingFileSent,
                        pendingSharedFiles: widget.pendingSharedFiles,
                        onSharedFilesSent: widget.onSharedFilesSent,
                        pendingClipboardItem: widget.pendingClipboardItem,
                        onClipboardItemSent: widget.onClipboardItemSent,
                        isGloballyBusy: isTransferring &&
                            svc.targetDeviceId != (active?.id ?? pinned.id),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                  // ─── الأجهزة الجديدة
                  if (newDevices.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.devices_rounded,
                      label: l10n.newDevices,
                      isDark: isDark,
                    ),
                    ...newDevices.map((device) => ConnectionWidget(
                          device: device,
                          isActive: true,
                          isPinned: false,
                          onPin: () => widget.onPin(device),
                          onUnpin: () => widget.onUnpin(device.id),
                          pendingFilePath: widget.pendingFilePath,
                          onPendingFileSent: widget.onPendingFileSent,
                          pendingSharedFiles: widget.pendingSharedFiles,
                          onSharedFilesSent: widget.onSharedFilesSent,
                          pendingClipboardItem: widget.pendingClipboardItem,
                          onClipboardItemSent: widget.onClipboardItemSent,
                          isGloballyBusy:
                              isTransferring && svc.targetDeviceId != device.id,
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Device List (Mobile/Tablet) ───────────────────────────────────────────

  Widget _buildDeviceList() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16;

    // الأجهزة الجديدة = المكتشفة وليست مثبتة
    final newDevices =
        widget.devices.where((d) => !widget.isPinned(d.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(l10n),
        Expanded(
          child: StreamBuilder<dynamic>(
            stream: TransferProgressService().progressStream,
            builder: (context, snapshot) {
              final svc = TransferProgressService();
              final isTransferring = svc.isTransferring;
              return ListView(
                physics: isTransferring
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                children: [
                  // ─── الأجهزة المثبتة
                  if (widget.pinnedDevices.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.push_pin_rounded,
                      label: l10n.pinnedDevices,
                      isDark: isDark,
                    ),
                    ...widget.pinnedDevices.map((pinned) {
                      final active = widget.devices
                          .where((d) => d.id == pinned.id)
                          .firstOrNull;
                      return ConnectionWidget(
                        device: active ?? pinned,
                        isActive: active != null,
                        isPinned: true,
                        onPin: () => widget.onPin(active ?? pinned),
                        onUnpin: () => widget.onUnpin(pinned.id),
                        pendingFilePath: widget.pendingFilePath,
                        onPendingFileSent: widget.onPendingFileSent,
                        pendingSharedFiles: widget.pendingSharedFiles,
                        onSharedFilesSent: widget.onSharedFilesSent,
                        pendingClipboardItem: widget.pendingClipboardItem,
                        onClipboardItemSent: widget.onClipboardItemSent,
                        isGloballyBusy: isTransferring &&
                            svc.targetDeviceId != (active?.id ?? pinned.id),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                  // ─── الأجهزة الجديدة
                  if (newDevices.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.devices_rounded,
                      label: l10n.newDevices,
                      isDark: isDark,
                    ),
                    ...newDevices.map((device) => ConnectionWidget(
                          device: device,
                          isActive: true,
                          isPinned: false,
                          onPin: () => widget.onPin(device),
                          onUnpin: () => widget.onUnpin(device.id),
                          pendingFilePath: widget.pendingFilePath,
                          onPendingFileSent: widget.onPendingFileSent,
                          pendingSharedFiles: widget.pendingSharedFiles,
                          onSharedFilesSent: widget.onSharedFilesSent,
                          pendingClipboardItem: widget.pendingClipboardItem,
                          onClipboardItemSent: widget.onClipboardItemSent,
                          isGloballyBusy:
                              isTransferring && svc.targetDeviceId != device.id,
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

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
      child: Row(
        children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.send,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                Text(
                  widget.devices.isEmpty
                      ? l10n.discovering
                      : '${widget.devices.length} ${l10n.availableDevices}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
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
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Live',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ]),
            ),
        ],
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _SectionHeader(
      {required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ]),
    );
  }
}
