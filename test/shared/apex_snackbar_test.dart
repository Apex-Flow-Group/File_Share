import 'package:apex_file_share/shared/apex_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner request: on a desktop window the snackbar stretched across the whole
/// window. On a wide window it is centered at Material's snackbar width
/// (344 to 672); on a phone it stays full width with its margins.
void main() {
  // The visible card, not the full-width box that positions it.
  final surface = find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first;

  Future<Rect> shown(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ApexSnackBar.info(context, 'Saved'),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return tester.getRect(surface);
  }

  testWidgets('desktop window: centered and no wider than 672', (tester) async {
    final r = await shown(tester, const Size(1480, 968));
    expect(r.width, lessThanOrEqualTo(672));
    expect(r.width, greaterThanOrEqualTo(344));
    expect(r.center.dx, closeTo(1480 / 2, 1));
  });

  testWidgets('phone: almost the full width, as before', (tester) async {
    final r = await shown(tester, const Size(400, 860));
    expect(r.width, greaterThan(400 - 40));
  });

  for (final show in <String, void Function(BuildContext)>{
    'success': (c) => ApexSnackBar.success(c, 'ok'),
    'error': (c) => ApexSnackBar.error(c, 'no'),
  }.entries) {
    testWidgets('${show.key} follows the same width', (tester) async {
      tester.view.physicalSize = const Size(1480, 968);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => show.value(context), child: const Text('go')),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface).width, lessThanOrEqualTo(672));
    });
  }
}
