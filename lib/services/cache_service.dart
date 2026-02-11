import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _prefix = 'news_cache_';
  static const _tsPrefix = 'news_cache_ts_';

  /// 뉴스 캐시 저장
  static Future<void> saveNews(String region, String category, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${region}_$category';
    await prefs.setString(key, jsonEncode(data));
    await prefs.setInt('$_tsPrefix${region}_$category', DateTime.now().millisecondsSinceEpoch);
  }

  /// 캐시된 뉴스 불러오기
  static Future<Map<String, dynamic>?> getNews(String region, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${region}_$category';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 캐시 나이(분) 반환. 캐시 없으면 -1
  static Future<int> getCacheAgeMinutes(String region, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('$_tsPrefix${region}_$category');
    if (ts == null) return -1;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)).inMinutes;
  }

  /// Pro 상태 저장/조회
  static Future<void> setProStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro', isPro);
  }

  static Future<bool> getProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_pro') ?? false;
  }
}
