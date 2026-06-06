import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/apex_apps_loader.dart';
import '../utils/apex_logger.dart';

class AppsSelectionScreen extends StatefulWidget {
  final Function(File, String) onAppSelected;

  const AppsSelectionScreen({required this.onAppSelected, super.key});

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  late Future<List<ApexAppInfo>> _appsFuture;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  void _loadApps() {
    _appsFuture = ApexAppsLoader.getInstalledApps();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('📱 ${l10n.installedApps}')),
      body: FutureBuilder<List<ApexAppInfo>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.discovering, style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('${l10n.connectionError}: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadApps();
                      });
                    },
                    child: Text(l10n.reconnectFailed),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apps, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.noApps, style: const TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final apps = snapshot.data!;

          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];

              try {
                final apkFile = File(app.apkPath);
                final sizeMB = (apkFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

                return ListTile(
                  leading: Image.memory(
                    app.icon,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.android, size: 40, color: Colors.grey);
                    },
                  ),
                  title: Text(app.name),
                  subtitle: Text('$sizeMB MB'),
                  trailing: const Icon(Icons.send, color: Colors.blue),
                  onTap: () async {
                    // Visual feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${l10n.selected}: ${app.name}'),
                        duration: const Duration(milliseconds: 500),
                      ),
                    );

                    ApexLogger.instance.log('APP_SELECT', '🖱️ تم النقر على التطبيق: ${app.name}', LogLevel.info);
                    try {
                      widget.onAppSelected(apkFile, app.name);
                      ApexLogger.instance.log('APP_SELECT', '✅ تم استدعاء callback بنجاح', LogLevel.success);

                      // Add small delay before popping to ensure callback completes
                      final wasMounted = context.mounted;
                      final canPop = wasMounted && Navigator.canPop(context);
                      await Future.delayed(const Duration(milliseconds: 100));

                      ApexLogger.instance.log('APP_SELECT', '🔙 جاري إغلاق النافذة...', LogLevel.info);
                      if (wasMounted && canPop && context.mounted) {
                        Navigator.pop(context);
                        ApexLogger.instance.log('APP_SELECT', '✅ تم إغلاق النافذة بنجاح', LogLevel.success);
                      } else {
                        ApexLogger.instance.log('APP_SELECT', '❌ لا يمكن إغلاق النافذة - canPop: $canPop, mounted: $wasMounted', LogLevel.warning);
                      }
                    } catch (e) {
                      ApexLogger.instance.log('APP_SELECT', '❌ خطأ في اختيار التطبيق: $e', LogLevel.error);
                      if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${l10n.connectionError}: $e')),
                      );
                      }
                    }
                  },
                );
              } catch (e) {
                return ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: Text(app.name),
                  subtitle: Text('${l10n.connectionError}: $e'),
                );
              }
            },
          );
        },
      ),
    );
  }
}
