import 'package:file_share_app/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SettingsService();
  });

  group('SettingsService', () {
    test('initial values are correct', () {
      expect(service.locale, null);
      expect(service.themeMode, ThemeMode.system);
    });

    test('setLocale updates locale and persists', () async {
      await service.setLocale(const Locale('ar'));
      expect(service.locale, const Locale('ar'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'ar');
    });

    test('setLocale with null removes locale', () async {
      await service.setLocale(const Locale('ar'));
      await service.setLocale(null);
      
      expect(service.locale, null);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('locale'), false);
    });

    test('setThemeMode updates theme and persists', () async {
      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('themeMode'), ThemeMode.dark.index);
    });

    test('loadSettings restores saved values', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale', 'en');
      await prefs.setInt('themeMode', ThemeMode.light.index);

      await service.loadSettings();

      expect(service.locale, const Locale('en'));
      expect(service.themeMode, ThemeMode.light);
    });

    test('getPreferences returns default values', () async {
      final prefs = await service.getPreferences();
      expect(prefs['sortBy'], 'date');
      expect(prefs['sortAscending'], false);
    });

    test('savePreference stores different types', () async {
      await service.savePreference('testString', 'value');
      await service.savePreference('testBool', true);
      await service.savePreference('testInt', 42);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('testString'), 'value');
      expect(prefs.getBool('testBool'), true);
      expect(prefs.getInt('testInt'), 42);
    });
  });
}
