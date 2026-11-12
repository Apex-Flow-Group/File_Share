import 'package:flutter/material.dart';

/// One icon for each action and page, on the phone, the computer and the TV
/// (owner decision): the same action drawn two ways reads as two actions. A
/// guard fails on these icons named anywhere else.
abstract final class ApexIcons {
  // ─── Pages: the same in the bottom bar, the sidebars and the TV bar. What
  // is selected is a lighter surface, not another icon.
  static const sendPage = Icons.send_rounded;
  static const receivePage = Icons.smartphone_rounded;
  static const filesPage = Icons.folder_rounded;
  static const findDevices = Icons.refresh_rounded;
  static const settings = Icons.settings_rounded;
  static const about = Icons.info_outline_rounded;
  static const menu = Icons.more_vert_rounded;
  static const close = Icons.close_rounded;

  // ─── A device's actions.
  /// The icon draws what the item does: a full star adds, an empty one
  /// removes. The favourites heading shows [favorite].
  static const favorite = Icons.star_rounded;
  static const unfavorite = Icons.star_border_rounded;
  static const sharedFolder = Icons.folder_shared_rounded;
  static const block = Icons.block_rounded;
  static const fold = Icons.expand_less_rounded;

  /// Sends what is in the message box.
  static const send = Icons.arrow_upward_rounded;

  /// Sends at once, where there is no message box (the TV).
  static const sendFilesNow = Icons.upload_file_rounded;
  static const sendApp = Icons.android_rounded;
  static const sendFolder = Icons.folder_zip_rounded;
  static const attach = Icons.add_rounded;
  static const paste = Icons.content_paste_rounded;
  static const offline = Icons.wifi_off_rounded;
  static const versionDiffers = Icons.system_update_rounded;
  static const busy = Icons.hourglass_top_rounded;
  static const network = Icons.wifi_rounded;
  static const direct = Icons.sensors_rounded;
}
