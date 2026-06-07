import 'package:apex_file_share/main.dart';
import 'package:apex_file_share/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FileShareApp smoke test', (WidgetTester tester) async {
    // Create a settings service for testing
    final settings = SettingsService();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(FileShareApp(settings: settings));
    
    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
