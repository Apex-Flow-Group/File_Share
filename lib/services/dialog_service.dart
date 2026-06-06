import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';


class DialogService {
  static Future<bool?> showConnectionRequest({
    required BuildContext context,
    required String deviceName,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) async {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;
    
    final titleFontSize = isSmall ? 16.0 : (isTablet ? 18.0 : 20.0);
    final bodyFontSize = isSmall ? 13.0 : (isTablet ? 14.0 : 15.0);
    final iconSize = isSmall ? 20.0 : (isTablet ? 24.0 : 28.0);
    final padding = isSmall ? 12.0 : (isTablet ? 16.0 : 20.0);
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.all(padding),
        title: Row(
          children: [
            Icon(Icons.phone_android, size: iconSize),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.connectionRequest,
                style: TextStyle(fontSize: titleFontSize),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmall ? size.width * 0.9 : (isTablet ? 500 : 600),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deviceWantsToConnect,
                  style: TextStyle(fontSize: bodyFontSize),
                ),
                SizedBox(height: isSmall ? 8 : 12),
                Container(
                  padding: EdgeInsets.all(isSmall ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.smartphone,
                        size: isSmall ? 24 : (isTablet ? 28 : 32),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: isSmall ? 8 : 12),
                      Expanded(
                        child: Text(
                          deviceName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmall ? 14 : (isTablet ? 16 : 18),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmall ? 8 : 12),
                Text(
                  l10n.acceptConnection,
                  style: TextStyle(fontSize: isSmall ? 11 : (isTablet ? 12 : 13)),
                ),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
        actions: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                onReject();
                Navigator.pop(context, false);
              },
              icon: Icon(Icons.close, size: isSmall ? 16 : 20),
              label: Text(
                l10n.reject,
                style: TextStyle(
                  fontSize: isSmall ? 12 : (isTablet ? 14 : 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
                padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          SizedBox(width: isSmall ? 8 : 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                onAccept();
                Navigator.pop(context, true);
              },
              icon: Icon(Icons.check, size: isSmall ? 16 : 20),
              label: Text(
                l10n.accept,
                style: TextStyle(
                  fontSize: isSmall ? 12 : (isTablet ? 14 : 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showDeleteConfirmation({
    required BuildContext context,
    required int fileCount,
  }) async {
    final l10n = AppLocalizations.of(context);
    bool deleteFromFolder = false;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Text(l10n.deleteFiles),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.deleteConfirmation} $fileCount ${l10n.files}؟',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              SwitchListTile(
                value: deleteFromFolder,
                onChanged: (value) => setDialogState(() => deleteFromFolder = value),
                title: Text(
                  l10n.deleteFromFolders,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  deleteFromFolder ? l10n.permanentDeleteWarning : l10n.deleteFromListOnly,
                  style: TextStyle(color: deleteFromFolder ? Colors.red : Colors.grey, fontSize: 12),
                ),
                activeTrackColor: Colors.red,
              ),
              if (deleteFromFolder) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cannotUndoWarning,
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(l10n.cancel),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, deleteFromFolder),
              icon: const Icon(Icons.delete),
              label: Text(l10n.delete),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    final l10n = AppLocalizations.of(context);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  static Future<void> showLoading({
    required BuildContext context,
    required String message,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
