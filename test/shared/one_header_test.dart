import 'dart:io';

import 'package:apex_file_share/shared/apex_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every screen and sheet head is ApexHeader: one drawn by hand sat under
/// the status bar, or inside its sheet's margin, while the others filled
/// the top.
void main() {
  test('no screen draws its own head', () {
    final byHand = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('apex_header.dart')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('bottom: Radius.circular(28)')) {
          byHand.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(byHand, isEmpty, reason: '${byHand.length} heads by hand; use ApexHeader');
  });

  testWidgets('on a phone it fills the top behind the status bar, its icon below it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(400, 800), padding: EdgeInsets.only(top: 24)),
        child: Scaffold(
          body: Column(children: [
            ApexHeader(icon: Icons.folder_rounded, color: Colors.orange, title: 'Files'),
          ]),
        ),
      ),
    ));
    expect(tester.getTopLeft(find.byType(ApexHeader)).dy, 0);
    expect(tester.getTopLeft(find.byIcon(Icons.folder_rounded)).dy, greaterThanOrEqualTo(24 + 16));
  });
}
