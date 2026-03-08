import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/apex_core.dart';
import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../screens/apps_selection_screen.dart';
import '../services/transfer_progress_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, sending, receiving }

class ConnectionWidget extends StatefulWidget {
  final Device device;
  final VoidCallback? onDisconnect;

  const ConnectionWidget({
    required this.device, super.key,
    this.onDisconnect,
  });

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget> {
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(l10n),
            const SizedBox(height: 16),
            _buildStatusIndicator(l10n),
            if (_status == ConnectionStatus.connected) ...[
              const SizedBox(height: 16),
              _buildActionButtons(l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _getDeviceIcon(widget.device.type),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.device.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${widget.device.ip}:${widget.device.port}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (_status == ConnectionStatus.connected)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => _status = ConnectionStatus.disconnected);
              widget.onDisconnect?.call();
            },
          ),
      ],
    );
  }

  Widget _buildStatusIndicator(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_status == ConnectionStatus.connecting ||
                  _status == ConnectionStatus.sending ||
                  _status == ConnectionStatus.receiving)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_getStatusColor()),
                  ),
                )
              else
                Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _getStatusText(l10n),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_status == ConnectionStatus.disconnected) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.tapToConnect),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _sendFile,
            icon: const Icon(Icons.attach_file),
            label: Text(l10n.sendFile),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _sendApp,
            icon: const Icon(Icons.android),
            label: Text(l10n.sendApp),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _connect() async {
    setState(() => _status = ConnectionStatus.connecting);
    
    // إرسال طلب اتصال (محاكاة - يحتاج تطبيق فعلي عبر HTTP)
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) {
      return;
    }
    setState(() => _status = ConnectionStatus.connected);
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _status = ConnectionStatus.sending);

    int successCount = 0;
    int totalFiles = result.files.length;

    try {
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        if (file.path == null) {
          continue;
        }

        final success = await ApexCore.instance.sendFile(
          file.path!,
          widget.device,
        );

        if (success) {
          successCount++;
        }
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        if (totalFiles == 1) {
          _showMessage(
            successCount > 0 ? l10n.fileSentSuccess : l10n.fileSendFailed,
            successCount > 0,
          );
        } else {
          _showMessage(
            '$successCount من $totalFiles ملف تم إرسالها بنجاح',
            successCount > 0,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showMessage('${l10n.connectionError}: $e', false);
      }
    } finally {
      TransferProgressService().clearProgress();
      if (mounted) {
        setState(() => _status = ConnectionStatus.connected);
      }
    }
  }

  Future<void> _sendApp() async {
    if (!mounted) {
      return;
    }
    final navContext = context;
    
    await Navigator.push(
      navContext,
      MaterialPageRoute(
        builder: (context) => AppsSelectionScreen(
          onAppSelected: (apkFile, appName) async {
            if (!mounted) {
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _status = ConnectionStatus.sending);

            try {
              final success = await ApexCore.instance.sendFileWithName(
                apkFile.path,
                '$appName.apk',
                widget.device,
              );

              if (!context.mounted) {
                return;
              }
              final currentL10n = AppLocalizations.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success ? currentL10n.appSent : '${currentL10n.sendFailed}: $appName'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            } catch (e) {
              if (!context.mounted) {
                return;
              }
              final errorL10n = AppLocalizations.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${errorL10n.connectionError}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            } finally {
              TransferProgressService().clearProgress();
              if (mounted) {
                setState(() => _status = ConnectionStatus.connected);
              }
            }
          },
        ),
      ),
    );
  }

  void _showMessage(String message, bool success) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case ConnectionStatus.disconnected:
        return Colors.grey;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.sending:
      case ConnectionStatus.receiving:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case ConnectionStatus.disconnected:
        return Icons.link_off;
      case ConnectionStatus.connecting:
        return Icons.sync;
      case ConnectionStatus.connected:
        return Icons.check_circle;
      case ConnectionStatus.sending:
        return Icons.upload;
      case ConnectionStatus.receiving:
        return Icons.download;
    }
  }

  String _getStatusText(AppLocalizations l10n) {
    switch (_status) {
      case ConnectionStatus.disconnected:
        return l10n.notConnected;
      case ConnectionStatus.connecting:
        return l10n.connecting;
      case ConnectionStatus.connected:
        return l10n.connected;
      case ConnectionStatus.sending:
        return l10n.sendingFileTo;
      case ConnectionStatus.receiving:
        return l10n.receiving;
    }
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.smartphone;
      case 'tablet':
        return Icons.tablet;
      case 'desktop':
        return Icons.computer;
      case 'tv':
        return Icons.tv;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }
}
