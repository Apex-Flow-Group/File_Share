import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/apex_core.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/device.dart';
import '../../../services/transfer_progress_service.dart';
import '../../../shared/apex_snackbar.dart';

/// Picks files and starts sending them to [device] through the same send as
/// every other, so they show as a line in its chat. False when nothing was
/// picked or another transfer is running (one at a time, as on the card).
Future<bool> attachFiles(BuildContext context, Device device) async {
  if (TransferProgressService().isTransferring) {
    ApexSnackBar.info(context, AppLocalizations.of(context).chatTransferBusy);
    return false;
  }
  final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
  final paths = [for (final f in picked?.files ?? const <PlatformFile>[]) if (f.path != null) f.path!];
  if (paths.isEmpty) {
    return false;
  }
  unawaited(ApexCore.instance.sendFiles(paths, device));
  return true;
}
