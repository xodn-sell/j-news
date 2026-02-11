class SourceItem {
  final String title;
  final String link;

  SourceItem({required this.title, required this.link});

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
    );
  }
}

class NewsResult {
  final String summary;
  final List<SourceItem> sources;
  final String? updatedAt;

  NewsResult({required this.summary, required this.sources, this.updatedAt});

  factory NewsResult.fromJson(Map<String, dynamic> json) {
    return NewsResult(
      summary: json['summary'] ?? '',
      sources: (json['sources'] as List<dynamic>)
          .map((s) => SourceItem.fromJson(s as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updated_at'],
    );
  }
}
