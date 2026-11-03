import 'package:apex_file_share/l10n/generated/app_localizations.dart';
import 'package:apex_file_share/mobile/widgets/connection_widget.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the Nearby badge fits a narrow phone with a large font', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const device = Device(
        id: 'nearby:x', name: 'Ali Phone', type: 'phone', ip: '192.168.100.200', endpointId: 'x');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(child: ConnectionWidget(device: device, onPin: _noop)),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
