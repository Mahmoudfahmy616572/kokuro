import 'package:shared_preferences/shared_preferences.dart';

/// Last N search queries, newest first — persisted on-device only.
class SearchHistory {
  static const _key = 'search_history';
  static const _max = 12;

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(_key) ?? <String>[])
        ..removeWhere((s) => s.toLowerCase() == q.toLowerCase());
      list.insert(0, q);
      if (list.length > _max) list.removeRange(_max, list.length);
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<void> remove(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? <String>[];
      list.removeWhere((s) => s == query);
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
