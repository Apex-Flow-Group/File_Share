import '../l10n/generated/app_localizations.dart';
import '../utils/file_utils.dart';

/// What the user reads when "Open folder" fails. Never the error itself: it is
/// English from a library, or "Exception: ...".
String folderOpenMessage(Object error, AppLocalizations l10n) =>
    error is FolderOpenError && error.missing ? l10n.folderMissing : l10n.openLocationFailed;
