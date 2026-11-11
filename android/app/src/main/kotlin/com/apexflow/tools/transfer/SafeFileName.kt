package com.apexflow.tools.transfer

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// The Kotlin copy of lib/core/files/safe_file_name.dart, for names another app
// gives us: DISPLAY_NAME is chosen by the sharing app, and
// "../../shared_prefs/x.xml" would write over this app's own settings.
// test/security/safe_file_name_parity_test.dart keeps the two copies equal.

private val invisibleMarks = setOf(
    0x061C, 0x200B, 0x200E, 0x200F,
    0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
    0x2066, 0x2067, 0x2068, 0x2069, 0xFEFF,
)

private val oddSpaces = setOf(
    0x00A0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006,
    0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000,
)

private const val FORBIDDEN = "<>:\"/\\|?*"

private val reserved = Regex("^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\\.|$)", RegexOption.IGNORE_CASE)

private const val MAX_BYTES = 255

// (?U): \s covers Unicode spaces, as Dart's \s does.
private val leadingDotsAndSpaces = Regex("(?U)^[.\\s]+")
private val trailingDotsAndSpaces = Regex("(?U)[.\\s]+$")

fun safeFileName(raw: String?, now: Date = Date()): String {
    val text = raw ?: ""
    val out = StringBuilder()
    var i = 0
    while (i < text.length) {
        val cp = text.codePointAt(i)
        i += Character.charCount(cp)
        if (cp in invisibleMarks) continue
        if (cp in oddSpaces) {
            out.append(' ')
            continue
        }
        val forbidden = cp < 0x20 || cp == 0x7F || (cp < 0x80 && FORBIDDEN.indexOf(cp.toChar()) >= 0)
        if (forbidden) out.append('_') else out.appendCodePoint(cp)
    }
    var name = trimEnds(out.toString())
    if (name.isEmpty()) {
        name = "file_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(now)
    }
    if (reserved.containsMatchIn(name)) {
        name = "_$name"
    }
    return fitBytes(name)
}

private fun trimEnds(s: String): String =
    s.replaceFirst(leadingDotsAndSpaces, "").replaceFirst(trailingDotsAndSpaces, "")

private fun utf8Size(s: String) = s.toByteArray(Charsets.UTF_8).size

private fun fitBytes(name: String): String {
    if (utf8Size(name) <= MAX_BYTES) return name
    val dot = name.lastIndexOf('.')
    val ext = if (dot > 0 && name.length - dot <= 16) name.substring(dot) else ""
    var base = if (ext.isEmpty()) name else name.substring(0, dot)
    val room = MAX_BYTES - utf8Size(ext)
    while (base.isNotEmpty() && utf8Size(base) > room) {
        base = base.substring(0, base.offsetByCodePoints(base.length, -1))
    }
    return trimEnds(base) + ext
}
