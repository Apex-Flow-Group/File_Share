import '../../../core/protocol/transfer_rules.dart';
import '../../../core/text/invisible_marks.dart';

/// A chat message from another device, as it may be shown: no control
/// characters but line breaks and tabs, no direction marks or overrides,
/// which reorder what is shown ("moc.knab<RLO>" read as a different
/// address), and no invisible characters, which make a copied text differ
/// from what was read (an account number with a hidden mark in it).
/// Null when nothing is left or it is longer than the limit.
String? cleanChatText(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final kept = raw.runes.where((r) => !_dropped(r)).toList();
  final text = String.fromCharCodes(kept);
  if (text.trim().isEmpty || kept.length > TransferRules.chatTextLimit) {
    return null;
  }
  return text;
}

bool _dropped(int r) =>
    isInvisibleMark(r) ||
    (r < 0x20 && r != 0x0A && r != 0x09) ||
    (r >= 0x7F && r <= 0x9F) ||
    r == 0x2028 ||
    r == 0x2029 || // line and paragraph separators
    (r >= 0x2060 && r <= 0x2064) || // word joiner and invisible operators
    (r >= 0x206A && r <= 0x206F) || // deprecated format characters
    (r >= 0xE0000 && r <= 0xE007F); // tag characters
