import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _sortByKey = 'sortBy';
  static const String _sortAscendingKey = 'sortAscending';

  Future<String> getSortBy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortByKey) ?? 'date';
  }

  Future<bool> getSortAscending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sortAscendingKey) ?? false;
  }

  Future<void> saveSortPreferences(String sortBy, bool ascending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortByKey, sortBy);
    await prefs.setBool(_sortAscendingKey, ascending);
  }
}
