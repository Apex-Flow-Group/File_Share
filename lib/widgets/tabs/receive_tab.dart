import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/device.dart';
import '../../models/transfer_progress.dart';
import '../../services/transfer_progress_service.dart';

enum ConnectionStatus {
  ready,
  connected,
  sending,
  receiving,
  busy,
}

class ReceiveTab extends StatefulWidget {
  final Device? localDevice;
  final bool isRunning;

  const ReceiveTab({
    required this.localDevice, required this.isRunning, super.key,
  });

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  ConnectionStatus _status = ConnectionStatus.ready;
  final _progressService = TransferProgressService();

  @override
  void initState() {
    super.initState();
    _progressService.progressStream.listen((progress) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (progress == null) {
          _status = ConnectionStatus.ready;
        } else if (progress.status == TransferStatus.transferring) {
          _status = ConnectionStatus.receiving;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    if (widget.localDevice == null || !widget.isRunning) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                isArabic ? 'غير متصل بالوايفاي' : 'Not Connected to WiFi',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'يرجى الاتصال بشبكة WiFi للمتابعة'
                    : 'Please connect to a WiFi network to continue',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? '• افتح إعدادات WiFi\n• اتصل بنفس الشبكة مع الجهاز الآخر\n• عد للتطبيق'
                            : '• Open WiFi settings\n• Connect to the same network as other device\n• Return to the app',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWideScreen ? 900 : double.infinity),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWideScreen ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWideScreen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildStatusCard(context, l10n),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildDeviceInfoCard(context, l10n),
                    ),
                  ],
                )
              else ...[
                _buildStatusCard(context, l10n),
                const SizedBox(height: 16),
                _buildDeviceInfoCard(context, l10n),
              ],
              const SizedBox(height: 16),
              _buildInstructionsCard(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppLocalizations l10n) {
    final statusInfo = _getStatusInfo(l10n);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              statusInfo['icon'] as IconData,
              size: 80,
              color: statusInfo['color'] as Color,
            ),
            const SizedBox(height: 16),
            Text(
              statusInfo['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: statusInfo['color'] as Color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              statusInfo['subtitle'] as String,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_status == ConnectionStatus.receiving || _status == ConnectionStatus.sending) ...[
              const SizedBox(height: 16),
              _buildProgressInfo(),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(context, l10n),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(AppLocalizations l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    switch (_status) {
      case ConnectionStatus.ready:
        return {
          'icon': Icons.check_circle_outline,
          'color': Colors.blue,
          'title': isArabic ? 'جاهز للاتصال' : 'Ready to Connect',
          'subtitle': l10n.instruction4,
        };
      case ConnectionStatus.connected:
        return {
          'icon': Icons.link,
          'color': Colors.green,
          'title': l10n.connected,
          'subtitle': isArabic ? 'متصل بجهاز آخر' : 'Connected to another device',
        };
      case ConnectionStatus.sending:
        return {
          'icon': Icons.upload,
          'color': Colors.orange,
          'title': isArabic ? 'جاري الإرسال' : 'Sending',
          'subtitle': isArabic ? 'يتم إرسال ملف...' : 'Sending file...',
        };
      case ConnectionStatus.receiving:
        return {
          'icon': Icons.download,
          'color': Colors.purple,
          'title': l10n.receiving,
          'subtitle': isArabic ? 'يتم استقبال ملف...' : 'Receiving file...',
        };
      case ConnectionStatus.busy:
        return {
          'icon': Icons.hourglass_empty,
          'color': Colors.red,
          'title': isArabic ? 'مشغول' : 'Busy',
          'subtitle': isArabic ? 'النظام مشغول حالياً' : 'System is currently busy',
        };
    }
  }

  Widget _buildProgressInfo() {
    return StreamBuilder<TransferProgress?>(
      stream: _progressService.progressStream,
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (progress == null) {
          return const SizedBox.shrink();
        }
        
        return Column(
          children: [
            LinearProgressIndicator(
              value: progress.percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.percentage.toStringAsFixed(0)}% - ${progress.speedFormatted}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    if (_status == ConnectionStatus.receiving || _status == ConnectionStatus.sending) {
      return ElevatedButton.icon(
        onPressed: () {
          _progressService.cancelTransfer();
        },
        icon: const Icon(Icons.stop),
        label: Text(isArabic ? 'إيقاف' : 'Stop'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      );
    }
    
    if (_status == ConnectionStatus.connected) {
      return ElevatedButton.icon(
        onPressed: () {
          setState(() => _status = ConnectionStatus.ready);
        },
        icon: const Icon(Icons.link_off),
        label: Text(isArabic ? 'قطع الاتصال' : 'Disconnect'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildDeviceInfoCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.thisDevice,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              context,
              Icons.phone_android,
              l10n.deviceName,
              widget.localDevice!.name,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.wifi,
              l10n.ipAddress,
              widget.localDevice!.ip,
              copyable: true,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.settings_ethernet,
              'Port',
              '${widget.localDevice!.port}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.devices,
              l10n.deviceType,
              _getDeviceTypeText(widget.localDevice!.type, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.howToReceive,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.instruction1}\n${l10n.instruction3}\n${l10n.instruction4}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool copyable = false,
  }) {
    final l10n = AppLocalizations.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.textCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: l10n.textCopied,
          ),
      ],
    );
  }

  String _getDeviceTypeText(String type, AppLocalizations l10n) {
    switch (type.toLowerCase()) {
      case 'phone':
        return l10n.phone;
      case 'tablet':
        return l10n.tablet;
      case 'desktop':
        return l10n.desktop;
      case 'tv':
        return 'TV';
      case 'web':
        return 'Web Browser';
      default:
        return l10n.defaultDevice;
    }
  }
}
