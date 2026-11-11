import 'dart:convert';

import '../text/invisible_marks.dart';

/// The one cleaning rule for every name that comes from another device or app
/// (HTTP, Nearby, share folder, downloads). It follows the strictest system,
/// Windows, so a name valid on Linux ("notes: draft?.txt") still saves there.
String safeFileName(String? raw, {DateTime Function() now = DateTime.now}) {
  final out = StringBuffer();
  for (final rune in (raw ?? '').runes) {
    if (isInvisibleMark(rune)) {
      continue;
    }
    if (_oddSpaces.contains(rune)) {
      out.write(' ');
      continue;
    }
    out.write(isControl(rune) || _forbidden.contains(rune) ? '_' : String.fromCharCode(rune));
  }
  var name = _trimEnds(out.toString());
  if (name.isEmpty) {
    name = 'file_${_stamp(now())}';
  }
  if (_reserved.hasMatch(name)) {
    name = '_$name';
  }
  return _fitBytes(name);
}

/// Spaces that look like " " but are another character: "WhatsApp<NBSP>Business.apk"
/// would sit next to "WhatsApp Business.apk" as a second file that cannot be
/// told apart or found by typing its name.
const _oddSpaces = <int>{
  0x00A0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006,
  0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000,
};

/// Windows forbids these; "/" and "\" would also make a path.
final _forbidden = '<>:"/\\|?*'.runes.toSet();

/// Device names Windows reserves, with or without an extension.
final _reserved = RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\.|$)', caseSensitive: false);

/// Leading dots would hide the file or climb up ("..");
/// Windows drops trailing dots and spaces silently.
String _trimEnds(String s) =>
    s.replaceFirst(RegExp(r'^[.\s]+'), '').replaceFirst(RegExp(r'[.\s]+$'), '');

const _maxBytes = 255;

String _fitBytes(String name) {
  if (utf8.encode(name).length <= _maxBytes) {
    return name;
  }
  final dot = name.lastIndexOf('.');
  final ext = dot > 0 && name.length - dot <= 16 ? name.substring(dot) : '';
  final base = (ext.isEmpty ? name : name.substring(0, dot)).runes.toList();
  final room = _maxBytes - utf8.encode(ext).length;
  while (base.isNotEmpty && utf8.encode(String.fromCharCodes(base)).length > room) {
    base.removeLast();
  }
  return '${_trimEnds(String.fromCharCodes(base))}$ext';
}

String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
}
