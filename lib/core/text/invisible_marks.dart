/// Direction and zero-width marks: invisible, but they reorder or hide text.
/// "photo<RLO>gpj.exe" is shown as "photoexe.jpg" and runs as a program.
const _marks = <int>{
  0x061C, // Arabic letter mark
  0x200B, // zero width space
  0x200E, 0x200F, // left-to-right / right-to-left mark
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // embeddings and overrides
  0x2066, 0x2067, 0x2068, 0x2069, // isolates
  0xFEFF, // byte order mark
};

bool isInvisibleMark(int rune) => _marks.contains(rune);

bool isControl(int rune) => rune < 0x20 || rune == 0x7F;
