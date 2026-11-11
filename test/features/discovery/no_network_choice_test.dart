import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Owner decision (2026-11-03): the Wi-Fi / LAN buttons are gone. The system
/// picks the outgoing network, so the choice did not steer anything, and on a
/// PC with the Windows hotspot on, "Wi-Fi" picked the hotspot address. The
/// presence packet now goes out on every network instead.
void main() {
  final lib = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('generated'));

  test('no code reads or offers a network choice', () {
    final offenders = [
      for (final f in lib)
        if (RegExp(r'NetworkMode|networkMode|network_mode').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
