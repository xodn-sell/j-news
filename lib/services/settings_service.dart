import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyViewMode = 'view_mode';
  static const _keyThemeMode = 'theme_mode';

  /// 보기 방식 저장/불러오기 ('swipe' | 'scroll')
  static Future<String> getViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyViewMode) ?? 'scroll';
  }

  static Future<void> saveViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyViewMode, mode);
  }

  /// 테마 모드 ('system' | 'light' | 'dark')
  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }
}
