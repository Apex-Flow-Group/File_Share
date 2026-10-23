import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NetworkMode { wifi, ethernet }

class SettingsService extends ChangeNotifier {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hasSeenIntro = false;
  NetworkMode _networkMode = NetworkMode.wifi;
  bool _sharedFolderEnabled = true;
  bool _allowShareUploads = true;

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get hasSeenIntro => _hasSeenIntro;
  NetworkMode get networkMode => _networkMode;
  bool get sharedFolderEnabled => _sharedFolderEnabled;
  bool get allowShareUploads => _allowShareUploads;

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

    // Load network mode
    final networkIndex = prefs.getInt('network_mode') ?? 0;
    _networkMode = NetworkMode.values[networkIndex];

    // Load share folder settings
    _sharedFolderEnabled = prefs.getBool('share_folder_enabled') ?? true;
    _allowShareUploads = prefs.getBool('share_allow_uploads') ?? true;

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

  Future<void> setNetworkMode(NetworkMode mode) async {
    _networkMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('network_mode', mode.index);
    notifyListeners();
  }

  Future<void> setSharedFolderEnabled(bool value) async {
    _sharedFolderEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('share_folder_enabled', value);
    notifyListeners();
  }

  Future<void> setAllowShareUploads(bool value) async {
    _allowShareUploads = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('share_allow_uploads', value);
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
