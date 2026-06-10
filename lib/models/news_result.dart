import 'dart:convert';

class QuizQuestion {
  final String question;
  final String type; // "ox" | "mc"
  final List<String> options;
  final int answerIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.type,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>?)
            ?.map((o) => o.toString())
            .toList() ??
        const ['O', 'X'];
    final rawIdx = (json['answer_index'] as num?)?.toInt() ?? 0;
    final safeIdx = (rawIdx >= 0 && rawIdx < opts.length) ? rawIdx : 0;
    return QuizQuestion(
      question: (json['question'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'ox',
      options: opts,
      answerIndex: safeIdx,
      explanation: (json['explanation'] as String?) ?? '',
    );
  }
}

class NewsItem {
  final String title;
  final String body;
  final String sourceLabel;
  final String sourceUrl;
  final List<GlossaryItem> glossary;
  final VisualData? visuals;
  final int? importance;
  final List<QuizQuestion> quiz;
  final String whyMatters;

  NewsItem({
    required this.title,
    required this.body,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.glossary,
    this.visuals,
    this.importance,
    this.quiz = const [],
    this.whyMatters = '',
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      sourceLabel: json['source_label'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      glossary: (json['glossary'] as List<dynamic>?)
              ?.map((g) => GlossaryItem.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      visuals: json['visuals'] != null
          ? VisualData.fromJson(json['visuals'] as Map<String, dynamic>)
          : null,
      importance: (json['importance'] as num?)?.toInt(),
      quiz: (json['quiz'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(QuizQuestion.fromJson)
              .toList() ??
          const [],
      whyMatters: json['why_matters'] ?? '',
    );
  }
}

class VisualData {
  final List<MetricData> metrics;
  final List<KeywordData> keywords;
  final String sentiment;
  final double sentimentScore;

  VisualData({
    required this.metrics,
    required this.keywords,
    required this.sentiment,
    required this.sentimentScore,
  });

  factory VisualData.fromJson(Map<String, dynamic> json) {
    return VisualData(
      metrics: (json['metrics'] as List<dynamic>?)
              ?.map((m) => MetricData.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((k) => KeywordData.fromJson(k as Map<String, dynamic>))
              .toList() ??
          [],
      sentiment: json['sentiment'] ?? 'neutral',
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class MetricData {
  final String label;
  final String value;
  final String type;

  MetricData({required this.label, required this.value, required this.type});

  factory MetricData.fromJson(Map<String, dynamic> json) {
    return MetricData(
      label: json['label'] ?? '',
      value: json['value']?.toString() ?? '',
      type: json['type'] ?? 'number',
    );
  }
}

class KeywordData {
  final String term;
  final int weight;

  KeywordData({required this.term, required this.weight});

  factory KeywordData.fromJson(Map<String, dynamic> json) {
    return KeywordData(
      term: json['term'] ?? '',
      weight: (json['weight'] as num?)?.toInt() ?? 5,
    );
  }
}

class GlossaryItem {
  final String term;
  final String definition;

  GlossaryItem({required this.term, required this.definition});

  factory GlossaryItem.fromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      term: json['term'] ?? '',
      definition: json['definition'] ?? '',
    );
  }
}

class InsightData {
  final String headline;
  final String summary;
  final List<String> points;
  final String outlook;
  final String mood; // optimistic | cautious | alarming | neutral

  const InsightData({
    required this.headline,
    required this.summary,
    required this.points,
    required this.outlook,
    required this.mood,
  });

  bool get isEmpty => headline.isEmpty && summary.isEmpty;
  bool get isStructured => headline.isNotEmpty;

  factory InsightData.fromJson(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return InsightData(
        headline: raw['headline'] as String? ?? '',
        summary: raw['summary'] as String? ?? '',
        points: (raw['points'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        outlook: raw['outlook'] as String? ?? '',
        mood: raw['mood'] as String? ?? 'neutral',
      );
    }
    // 구버전 문자열 포맷 fallback
    return InsightData(
      headline: '',
      summary: raw?.toString() ?? '',
      points: [],
      outlook: '',
      mood: 'neutral',
    );
  }

  Map<String, dynamic> toJson() => {
    'headline': headline,
    'summary': summary,
    'points': points,
    'outlook': outlook,
    'mood': mood,
  };
}

class DialogueTurn {
  final String speaker; // "A" or "B"
  final String text;

  const DialogueTurn({required this.speaker, required this.text});

  factory DialogueTurn.fromJson(Map<String, dynamic> json) {
    return DialogueTurn(
      speaker: (json['speaker'] ?? 'A').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

class NewsResult {
  final List<NewsItem> items;
  final InsightData insight;
  final String? updatedAt;
  final List<DialogueTurn> dialogue;

  NewsResult({
    required this.items,
    required this.insight,
    this.updatedAt,
    this.dialogue = const [],
  });

  factory NewsResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _normalizePayload(json);

    final dialogueRaw = json['dialogue'];
    final List<DialogueTurn> dialogue = (dialogueRaw is List)
        ? dialogueRaw
            .whereType<Map<String, dynamic>>()
            .map(DialogueTurn.fromJson)
            .where((t) => t.text.isNotEmpty)
            .toList()
        : const [];

    return NewsResult(
      items: (data['items'] as List<dynamic>?)
              ?.map((i) => NewsItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      insight: InsightData.fromJson(data['insight'] ?? json['insight']),
      updatedAt: json['updated_at'],
      dialogue: dialogue,
    );
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> json) {
    final dynamic summary = json['summary'];

    if (summary != null) {
      final Map<String, dynamic>? parsed = _parseToMap(summary);
      if (parsed != null) return parsed;
      return {
        'items': [],
        'insight': summary.toString(),
      };
    }

    return json;
  }

  static Map<String, dynamic>? _parseToMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is! String) return null;

    final dynamic direct = _tryJsonDecode(value);
    if (direct is Map<String, dynamic>) return direct;

    if (direct is String) {
      final dynamic nested = _tryJsonDecode(direct);
      if (nested is Map<String, dynamic>) return nested;
    }

    String trimmed = value.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed
          .replaceFirst(RegExp(r'^```json\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
      final dynamic fenced = _tryJsonDecode(trimmed);
      if (fenced is Map<String, dynamic>) return fenced;
    }

    final int start = trimmed.indexOf('{');
    final int end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final dynamic fragment =
          _tryJsonDecode(trimmed.substring(start, end + 1));
      if (fragment is Map<String, dynamic>) return fragment;
    }

    return null;
  }

  static dynamic _tryJsonDecode(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      return null;
    }
  }
}
