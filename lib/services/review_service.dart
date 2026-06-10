import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_result.dart';

/// SRS 복습 카드 1장. question 문자열이 고유 키.
class ReviewCard {
  final String question;
  final String type; // "ox" | "mc"
  final List<String> choices;
  final int answerIndex;
  final String explanation;
  final String articleTitle;
  final int stage; // 1~5 (Leitner)
  final String nextReviewDate; // YYYY-MM-DD
  final bool mastered;
  final String createdDate; // YYYY-MM-DD

  const ReviewCard({
    required this.question,
    required this.type,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
    required this.articleTitle,
    required this.stage,
    required this.nextReviewDate,
    required this.mastered,
    required this.createdDate,
  });

  ReviewCard copyWith({int? stage, String? nextReviewDate, bool? mastered}) {
    return ReviewCard(
      question: question,
      type: type,
      choices: choices,
      answerIndex: answerIndex,
      explanation: explanation,
      articleTitle: articleTitle,
      stage: stage ?? this.stage,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      mastered: mastered ?? this.mastered,
      createdDate: createdDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'type': type,
        'choices': choices,
        'answerIndex': answerIndex,
        'explanation': explanation,
        'articleTitle': articleTitle,
        'stage': stage,
        'nextReviewDate': nextReviewDate,
        'mastered': mastered,
        'createdDate': createdDate,
      };

  factory ReviewCard.fromJson(Map<String, dynamic> json) {
    return ReviewCard(
      question: (json['question'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'ox',
      choices: (json['choices'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          const ['O', 'X'],
      answerIndex: (json['answerIndex'] as num?)?.toInt() ?? 0,
      explanation: (json['explanation'] as String?) ?? '',
      articleTitle: (json['articleTitle'] as String?) ?? '',
      stage: (json['stage'] as num?)?.toInt() ?? 1,
      nextReviewDate: (json['nextReviewDate'] as String?) ?? '',
      mastered: (json['mastered'] as bool?) ?? false,
      createdDate: (json['createdDate'] as String?) ?? '',
    );
  }

  /// 정답 텍스트 (뒷면 표시용).
  String get answerLabel =>
      (answerIndex >= 0 && answerIndex < choices.length)
          ? choices[answerIndex]
          : '';
}

/// 복습 통계 (홈/완료 화면 표시용).
class ReviewStats {
  final int totalCards;
  final int masteredCount;
  final int dueToday;

  const ReviewStats({
    required this.totalCards,
    required this.masteredCount,
    required this.dueToday,
  });
}

/// Leitner 5단계 간격 반복(SRS) 서비스.
///
/// - 간격: 1단계=1일, 2=3일, 3=7일, 4=14일, 5=30일
/// - 정답 → 다음 단계, 오답 → 1단계 리셋
/// - 5단계에서 정답 → 마스터(졸업). 복습 큐 제외, 통계용 보존.
/// - 뉴스 시의성: 생성 45일 경과 + 미마스터 카드는 due에서 자동 제외(만료).
class ReviewService {
  static const _cardsKey = 'review_cards';

  /// 단계별 다음 복습 간격(일). index = stage - 1.
  static const _intervalDays = [1, 3, 7, 14, 30];

  static const maxStage = 5;

  /// 미마스터 카드 만료 기한(일) — 뉴스 시의성 고려.
  static const expiryDays = 45;

  /// 오늘 날짜 YYYY-MM-DD (로컬).
  static String _today() => _fmt(DateTime.now());

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _addDays(String ymd, int days) {
    final base = DateTime.tryParse(ymd) ?? DateTime.now();
    return _fmt(base.add(Duration(days: days)));
  }

  // ── 저장소 ────────────────────────────────────────────────

  /// question 문자열 키 → 카드 JSON 맵으로 저장 (중복 자동 방지).
  static Future<Map<String, ReviewCard>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(k, ReviewCard.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveAll(Map<String, ReviewCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardsKey,
      jsonEncode(cards.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  // ── 공개 API ──────────────────────────────────────────────

  /// 퀴즈 문항을 복습 카드로 등록. question 문자열로 중복 방지.
  /// 신규 카드는 1단계 → 내일 due (Day2 재방문 훅).
  static Future<void> addCard(QuizQuestion q, String articleTitle) async {
    if (q.question.isEmpty) return;
    final cards = await _loadAll();
    if (cards.containsKey(q.question)) return; // 이미 등록됨
    final today = _today();
    cards[q.question] = ReviewCard(
      question: q.question,
      type: q.type,
      choices: q.options,
      answerIndex: q.answerIndex,
      explanation: q.explanation,
      articleTitle: articleTitle,
      stage: 1,
      nextReviewDate: _addDays(today, _intervalDays[0]),
      mastered: false,
      createdDate: today,
    );
    await _saveAll(cards);
  }

  /// 오늘 복습할 카드 — nextReviewDate ≤ 오늘, 미마스터, 미만료.
  static Future<List<ReviewCard>> dueCards() async {
    final cards = await _loadAll();
    final today = _today();
    return cards.values.where((c) => _isDue(c, today)).toList()
      ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
  }

  static bool _isDue(ReviewCard c, String today) {
    if (c.mastered) return false;
    if (c.nextReviewDate.isEmpty || c.nextReviewDate.compareTo(today) > 0) {
      return false;
    }
    // 생성 45일 경과 → 만료 (뉴스 시의성)
    if (c.createdDate.isNotEmpty &&
        _addDays(c.createdDate, expiryDays).compareTo(today) < 0) {
      return false;
    }
    return true;
  }

  /// 복습 결과 기록. 정답=다음 단계(5단계면 마스터), 오답=1단계 리셋.
  static Future<void> recordResult(String cardKey, bool correct) async {
    final cards = await _loadAll();
    final card = cards[cardKey];
    if (card == null) return;
    final today = _today();

    if (correct) {
      if (card.stage >= maxStage) {
        // 졸업 — 큐 제외, masteredCount 통계용 보존
        cards[cardKey] = card.copyWith(mastered: true);
      } else {
        final next = card.stage + 1;
        cards[cardKey] = card.copyWith(
          stage: next,
          nextReviewDate: _addDays(today, _intervalDays[next - 1]),
        );
      }
    } else {
      // 오답 — 1단계 리셋
      cards[cardKey] = card.copyWith(
        stage: 1,
        nextReviewDate: _addDays(today, _intervalDays[0]),
      );
    }
    await _saveAll(cards);
  }

  /// 누적 통계: 총 카드 / 마스터 수 / 오늘 due 수.
  static Future<ReviewStats> stats() async {
    final cards = await _loadAll();
    final today = _today();
    return ReviewStats(
      totalCards: cards.length,
      masteredCount: cards.values.where((c) => c.mastered).length,
      dueToday: cards.values.where((c) => _isDue(c, today)).length,
    );
  }
}
