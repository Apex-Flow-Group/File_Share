import 'invisible_marks.dart';

/// A short text from another device shown to the user (a device name):
/// no control characters, no direction marks, one line, at most [maxRunes].
String cleanLabel(String? raw, {int maxRunes = 64}) {
  final kept = (raw ?? '')
      .runes
      .where((r) => !isInvisibleMark(r))
      .map((r) => isControl(r) ? 0x20 : r)
      .toList();
  final text = String.fromCharCodes(kept).replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = text.runes.toList();
  return runes.length <= maxRunes ? text : String.fromCharCodes(runes.take(maxRunes)).trim();
}
