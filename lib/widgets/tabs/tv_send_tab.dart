import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/apex_core.dart';
import '../../l10n/app_localizations.dart';
import '../../models/device.dart';

class TVSendTab extends StatefulWidget {
  final List<Device> devices;
  final bool isRunning;

  const TVSendTab({required this.devices, required this.isRunning, super.key});

  @override
  State<TVSendTab> createState() => _TVSendTabState();
}

class _TVSendTabState extends State<TVSendTab> {
  int _selectedDeviceIndex = 0;
  final FocusNode _pickFileFocus = FocusNode();
  final List<FocusNode> _deviceFocusNodes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickFileFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(TVSendTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.devices.length != oldWidget.devices.length) {
      _updateFocusNodes();
    }
  }

  void _updateFocusNodes() {
    for (var node in _deviceFocusNodes) {
      node.dispose();
    }
    _deviceFocusNodes.clear();
    for (int i = 0; i < widget.devices.length; i++) {
      _deviceFocusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    _pickFileFocus.dispose();
    for (var node in _deviceFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.send, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          _buildPickFileButton(l10n),
          const SizedBox(height: 32),
          Text(l10n.availableDevices, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(child: _buildDevicesList(l10n)),
        ],
      ),
    );
  }

  Widget _buildPickFileButton(AppLocalizations l10n) {
    return Focus(
      focusNode: _pickFileFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && widget.devices.isNotEmpty) {
            _deviceFocusNodes[0].requestFocus();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.space) {
            _pickFile();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            decoration: BoxDecoration(
              border: hasFocus ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload, size: 32),
              label: Text(l10n.pickFile, style: const TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDevicesList(AppLocalizations l10n) {
    if (!widget.isRunning) {
      return Center(child: Text(l10n.systemNotRunning, style: const TextStyle(fontSize: 18)));
    }

    if (widget.devices.isEmpty) {
      return Center(child: Text(l10n.noDevicesFound, style: const TextStyle(fontSize: 18)));
    }

    _updateFocusNodes();

    return ListView.builder(
      itemCount: widget.devices.length,
      itemBuilder: (context, index) {
        final device = widget.devices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildDeviceCard(device, index, l10n),
        );
      },
    );
  }

  Widget _buildDeviceCard(Device device, int index, AppLocalizations l10n) {
    return Focus(
      focusNode: _deviceFocusNodes[index],
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (index == 0) {
              _pickFileFocus.requestFocus();
            } else {
              _deviceFocusNodes[index - 1].requestFocus();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (index < widget.devices.length - 1) {
              _deviceFocusNodes[index + 1].requestFocus();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.space) {
            setState(() => _selectedDeviceIndex = index);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final isSelected = _selectedDeviceIndex == index;
          return Container(
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
              border: hasFocus 
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                : Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(Icons.devices, size: 40, color: Theme.of(context).colorScheme.primary),
              title: Text(device.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text('${device.ip}:${device.port}', style: const TextStyle(fontSize: 16)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green, size: 32) : null,
              onTap: () => setState(() => _selectedDeviceIndex = index),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context);
    
    if (widget.devices.isEmpty) {
      _showMessage(l10n.noDevicesFound);
      return;
    }

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.path == null) {
      return;
    }

    final targetDevice = widget.devices[_selectedDeviceIndex];
    
    if (!mounted) {
      return;
    }
    _showMessage('${l10n.sending} ${file.name}...');

    final success = await ApexCore.instance.sendFile(file.path!, targetDevice);
    
    if (mounted) {
      _showMessage(success 
        ? '✅ ${l10n.fileSentSuccessfully}'
        : '❌ ${l10n.sendFailed}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))),
    );
  }
}
