import '../features/receive/data/sender_log.dart';
import '../l10n/generated/app_localizations.dart';

/// "From: Ahmed's phone · Yesterday 14:20", under a received file. The name
/// is isolated in its own direction: a Latin name would otherwise join the
/// digits after it, and an Arabic line would show the date before the name.
String senderLineText(AppLocalizations l10n, SenderLine line, {DateTime? now}) => l10n.senderLine(
    '${String.fromCharCode(0x2068)}${line.name}${String.fromCharCode(0x2069)}',
    whenText(l10n, line.at, now: now ?? DateTime.now()));

/// When something happened, in local time: "Today 14:20", "Yesterday 14:20",
/// or "2026-11-03 14:20". The one place the app writes a day and time.
String whenText(AppLocalizations l10n, DateTime at, {required DateTime now}) {
  final local = at.toLocal();
  final today = now.toLocal();
  final time = '${_two(local.hour)}:${_two(local.minute)}';
  final day = DateTime(local.year, local.month, local.day);
  if (day == DateTime(today.year, today.month, today.day)) {
    return l10n.whenToday(time);
  }
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return l10n.whenYesterday(time);
  }
  return '${local.year}-${_two(local.month)}-${_two(local.day)} $time';
}

String _two(int n) => n.toString().padLeft(2, '0');
