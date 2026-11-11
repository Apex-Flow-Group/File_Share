import '../l10n/generated/app_localizations.dart';
import '../platform/open_with_app.dart';
import '../utils/file_utils.dart';

/// What the user reads when opening a file fails. Never the error itself: it
/// is English from a library, or "Exception: ...".
String fileOpenMessage(Object error, AppLocalizations l10n) => switch (error) {
      FileOpenError(result: FileOpenResult.missing) => l10n.fileMissing,
      FileOpenError(result: FileOpenResult.noApp) => l10n.noAppForFile,
      _ => l10n.openFileFailed,
    };
