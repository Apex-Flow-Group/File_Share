import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/delete_files_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deleting always deletes, after one confirmation. The sheet once had a
/// switch that, left off, "deleted" files that stayed in the list.
void main() {
  Future<Future<bool>> open(WidgetTester tester, int count, String lang) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
    final result = DeleteFilesSheet.show(ctx, fileCount: count);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the sheet has no switch and deleting confirms with true', (tester) async {
    final result = await open(tester, 3, 'en');
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Delete 3 files?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_rounded).last);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('cancel returns false', (tester) async {
    final result = await open(tester, 1, 'en');
    expect(find.text('Delete 1 file?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('the question follows the Arabic plural', (tester) async {
    for (final (count, text) in [
      (1, 'حذف ملف واحد؟'),
      (2, 'حذف ملفين؟'),
      (5, 'حذف 5 ملفات؟'),
      (11, 'حذف 11 ملفاً؟'),
      (100, 'حذف 100 ملف؟'),
    ]) {
      final result = await open(tester, count, 'ar');
      expect(find.text(text), findsOneWidget, reason: '$count');
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await result;
    }
  });
}
