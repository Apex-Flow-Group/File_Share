import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hasSeenIntro = false;

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get hasSeenIntro => _hasSeenIntro;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load locale
    final languageCode = prefs.getString('locale_language');
    final countryCode = prefs.getString('locale_country');
    if (languageCode != null) {
      _locale = countryCode != null
          ? Locale(languageCode, countryCode)
          : Locale(languageCode);
    }

    // Load theme mode
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    // Load intro seen status
    _hasSeenIntro = prefs.getBool('has_seen_intro') ?? false;

    notifyListeners();
  }
  
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale != null) {
      await prefs.setString('locale_language', locale.languageCode);
      if (locale.countryCode != null) {
        await prefs.setString('locale_country', locale.countryCode!);
      }
    } else {
      await prefs.remove('locale_language');
      await prefs.remove('locale_country');
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> markIntroAsSeen() async {
    _hasSeenIntro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_intro', true);
    notifyListeners();
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'sortBy': prefs.getString('sortBy') ?? 'date',
      'sortAscending': prefs.getBool('sortAscending') ?? false,
    };
  }

  Future<void> savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
    notifyListeners();
  }
}
