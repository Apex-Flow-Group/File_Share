import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Asks before blocking [name] (phone and computer). True when confirmed.
Future<bool> confirmBlock(BuildContext context, String name) async {
  final l10n = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.chatBlockQuestion(name)),
      content: Text(l10n.chatBlockDetail),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.chatBlock, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return yes ?? false;
}
