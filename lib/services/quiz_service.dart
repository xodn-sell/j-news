import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_result.dart';

class QuizService {
  static const _attemptsKey = 'quiz_attempts';

  /// 읽은 기사들에서 퀴즈 문항 수집. 기사당 1문제 우선, 최대 4문항.
  static List<QuizQuestion> buildSessionQuiz(List<NewsItem> items) {
    final result = <QuizQuestion>[];
    for (final item in items) {
      if (item.quiz.isEmpty) continue;
      result.add(item.quiz.first);
      if (result.length >= 4) break;
    }
    return result;
  }

  /// 시도 기록 로컬 저장 (Phase 2 복습 대비 단순 누적).
  static Future<void> recordAttempt({
    required String question,
    required String articleTitle,
    required bool correct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_attemptsKey);
    final List<dynamic> list = raw != null ? jsonDecode(raw) as List : [];
    list.add({
      'q': question,
      'title': articleTitle,
      'correct': correct,
      'date': DateTime.now().toIso8601String().substring(0, 10),
    });
    await prefs.setString(_attemptsKey, jsonEncode(list));
  }
}
