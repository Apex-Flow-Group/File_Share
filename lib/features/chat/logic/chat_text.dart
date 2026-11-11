import '../../../core/protocol/transfer_rules.dart';

/// A chat message from another device, as it may be shown: no control
/// characters but line breaks and tabs, and no direction overrides, which
/// reorder what is shown ("moc.knab<RLO>" read as a different address).
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
    (r < 0x20 && r != 0x0A && r != 0x09) ||
    (r >= 0x7F && r <= 0x9F) ||
    (r >= 0x202A && r <= 0x202E) ||
    (r >= 0x2066 && r <= 0x2069) ||
    r == 0xFEFF;
