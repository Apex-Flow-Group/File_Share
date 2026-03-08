import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/device.dart';
import '../connection_widget.dart';
import '../text_chat_sheet.dart';

class SendTab extends StatefulWidget {
  final List<Device> devices;
  final bool isRunning;

  const SendTab({
    required this.devices, required this.isRunning, super.key,
  });

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: _buildDeviceList(),
      floatingActionButton: widget.devices.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showTextChat,
              icon: const Icon(Icons.message),
              label: Text(l10n.sendText),
            ),
    );
  }

  Widget _buildDeviceList() {
    final l10n = AppLocalizations.of(context);

    if (widget.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isRunning)
              RotationTransition(
                turns: _radarController,
                child: Icon(
                  Icons.radar,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.devices,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
            const SizedBox(height: 16),
            Text(
              l10n.noDevicesFound,
              style: Theme.of(context).textTheme.titleMedium,
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: widget.devices.length,
      itemBuilder: (context, index) {
        final device = widget.devices[index];
        return ConnectionWidget(
          device: device,
          onDisconnect: () {
            // Handle disconnect
          },
        );
      },
    );
  }

  void _showTextChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TextChatSheet(devices: widget.devices),
    );
  }
}
