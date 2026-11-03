import 'dart:io';

import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/tv/widgets/tv_file_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Choosing a folder to send with the TV remote, inside the app's own browser.
void main() {
  late Directory root;
  late String? picked;
  late bool closed;

  setUp(() {
    root = Directory.systemTemp.createTempSync('apex_tv_folder_');
    Directory('${root.path}/Photos').createSync();
    File('${root.path}/Photos/a.jpg').writeAsStringSync('x');
    File('${root.path}/notes.txt').writeAsStringSync('x');
  });

  tearDown(() => root.deleteSync(recursive: true));

  Widget host(Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                autofocus: true,
                onPressed: () async {
                  picked = await showTVFolderBrowser(context, root: root.path, list: _listNow);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Locale locale) async {
    picked = null;
    closed = false;
    await tester.pumpWidget(host(locale));
    await press(tester, LogicalKeyboardKey.select);
  }

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('the remote opens a folder and sends it ($locale)', (tester) async {
      await open(tester, locale);
      await press(tester, LogicalKeyboardKey.select); // folders come first: open Photos
      expect(find.text('a.jpg'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowDown); // .. -> a.jpg
      await press(tester, LogicalKeyboardKey.arrowDown); // a.jpg -> send this folder
      await press(tester, LogicalKeyboardKey.select);
      expect(closed, isTrue);
      expect(_slashes(picked), _slashes('${root.path}/Photos'));
    });
  }

  testWidgets('the whole storage cannot be sent as one folder', (tester) async {
    await open(tester, const Locale('en'));
    await press(tester, LogicalKeyboardKey.arrowDown); // Photos -> notes.txt
    await press(tester, LogicalKeyboardKey.arrowDown); // -> footer
    await press(tester, LogicalKeyboardKey.select);
    expect(closed, isFalse);
  });

  testWidgets('at the storage root the title and button say what to do', (tester) async {
    await open(tester, const Locale('ar'));
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.storageLabel), findsOneWidget,
        reason: 'The last part of /storage/emulated/0 is "0".');
    expect(find.text(l10n.pickFolder), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select); // open Photos
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text(l10n.sendThisFolder), findsOneWidget);
  });

  testWidgets('a file is not picked in folder mode', (tester) async {
    await open(tester, const Locale('en'));
    await press(tester, LogicalKeyboardKey.select); // open Photos
    await press(tester, LogicalKeyboardKey.arrowDown); // -> a.jpg
    await press(tester, LogicalKeyboardKey.select);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.sendThisFolder), findsOneWidget,
        reason: 'The main button still sends the folder, not a picked file.');
  });

  // The remote's Back reaches the app as a route pop, not as a key.
  testWidgets('Back leaves the folder, then closes without sending', (tester) async {
    await open(tester, const Locale('ar'));
    await press(tester, LogicalKeyboardKey.select); // open Photos
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('notes.txt'), findsOneWidget, reason: 'Back goes up one folder');
    expect(closed, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked, isNull);
  });

  testWidgets('in file mode the list leads down to the send button', (tester) async {
    late List<String>? files;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            autofocus: true,
            onPressed: () async =>
                files = await showTVFileBrowser(context, root: root.path, list: _listNow),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown); // Photos -> notes.txt
    await press(tester, LogicalKeyboardKey.select); // pick notes.txt
    await press(tester, LogicalKeyboardKey.arrowDown); // -> send
    await press(tester, LogicalKeyboardKey.select);
    expect(files?.map(_slashes), [_slashes('${root.path}/notes.txt')]);
  });
}

// Disk I/O started inside testWidgets' fake async never completes; the
// real temp folder is listed at once instead.
Future<List<FileSystemEntity>> _listNow(Directory dir) async => dir.listSync();

// Windows lists children with a backslash.
String? _slashes(String? path) => path?.replaceAll(r'\', '/');
