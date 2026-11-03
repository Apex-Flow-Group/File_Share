import '../../../l10n/generated/app_localizations.dart';
import '../../../services/clipboard_monitor_service.dart';

/// How a copied item is named on screen and in notifications. Copied text is
/// often a password, so only its length is shown, never its content.
/// [typeShown]: the type and file count are already shown beside the label
/// (the device card's chip), so text is named by its length alone and several
/// files by the first one's name.
String clipboardLabel(AppLocalizations l10n, ClipboardItem item, {bool typeShown = false}) {
  final text = item.text;
  if (item.type == ClipboardItemType.text && text != null) {
    final length = text.runes.length;
    return typeShown ? l10n.clipboardCharCount(length) : l10n.clipboardTextLength(length);
  }
  if (item.paths.length > 1 && !typeShown) {
    return l10n.clipboardFileCount(item.paths.length);
  }
  if (item.paths.isEmpty) {
    return '';
  }
  return item.paths.first.replaceAll('\\', '/').split('/').last;
}
