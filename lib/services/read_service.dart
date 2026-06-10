import 'package:shared_preferences/shared_preferences.dart';

class ReadService {
  static const _key = 'read_articles';
  static const _maxStored = 300;

  static String _id(String url, String title) {
    return url.isNotEmpty ? url : title;
  }

  static Future<Set<String>> getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  static Future<bool> isRead(String url, String title) async {
    final ids = await getReadIds();
    return ids.contains(_id(url, title));
  }

  static Future<void> markRead(String url, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    final id = _id(url, title);
    if (!ids.contains(id)) {
      ids.add(id);
      if (ids.length > _maxStored) ids.removeRange(0, ids.length - _maxStored);
      await prefs.setStringList(_key, ids);
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
