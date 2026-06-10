import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_result.dart';

/// 세션 퀴즈 문항 + 출처 기사 제목 (복습 카드 등록용).
class SessionQuizItem {
  final QuizQuestion question;
  final String articleTitle;

  const SessionQuizItem({required this.question, required this.articleTitle});
}

class QuizService {
  static const _attemptsKey = 'quiz_attempts';

  /// 읽은 기사들에서 퀴즈 문항 수집. 기사당 1문제 우선, 최대 4문항.
  static List<SessionQuizItem> buildSessionQuiz(List<NewsItem> items) {
    final result = <SessionQuizItem>[];
    for (final item in items) {
      if (item.quiz.isEmpty) continue;
      result.add(SessionQuizItem(
        question: item.quiz.first,
        articleTitle: item.title,
      ));
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
