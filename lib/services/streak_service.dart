import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const _keyLastDate = 'streak_last_date';
  static const _keyCount = 'streak_count';

  // 오늘 완독 기록. 반환: 현재 스트릭 일수
  static Future<int> recordCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateStr(DateTime.now());
    final last = prefs.getString(_keyLastDate) ?? '';
    final count = prefs.getInt(_keyCount) ?? 0;

    if (last == today) return count; // 오늘 이미 기록됨

    final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
    final newCount = (last == yesterday) ? count + 1 : 1;

    await prefs.setString(_keyLastDate, today);
    await prefs.setInt(_keyCount, newCount);
    return newCount;
  }

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateStr(DateTime.now());
    final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
    final last = prefs.getString(_keyLastDate) ?? '';
    if (last != today && last != yesterday) {
      // 스트릭 끊김
      await prefs.setInt(_keyCount, 0);
      return 0;
    }
    return prefs.getInt(_keyCount) ?? 0;
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
