import 'dart:convert';

class NewsItem {
  final String title;
  final String body;
  final String sourceLabel;
  final String sourceUrl;
  final List<GlossaryItem> glossary;

  NewsItem({
    required this.title,
    required this.body,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.glossary,
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

class NewsResult {
  final List<NewsItem> items;
  final String insight;
  final String? updatedAt;

  NewsResult({
    required this.items,
    required this.insight,
    this.updatedAt,
  });

  factory NewsResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _normalizePayload(json);

    return NewsResult(
      items: (data['items'] as List<dynamic>?)
              ?.map((i) => NewsItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      insight: data['insight'] ?? '',
      updatedAt: json['updated_at'],
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
