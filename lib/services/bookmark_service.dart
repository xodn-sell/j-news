import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkItem {
  final String title;
  final String body;
  final String? sourceLabel;
  final String? sourceUrl;
  final String savedAt;

  BookmarkItem({
    required this.title,
    required this.body,
    this.sourceLabel,
    this.sourceUrl,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'sourceLabel': sourceLabel,
    'sourceUrl': sourceUrl,
    'savedAt': savedAt,
  };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    sourceLabel: json['sourceLabel'],
    sourceUrl: json['sourceUrl'],
    savedAt: json['savedAt'] ?? '',
  );
}

class BookmarkService {
  static const _key = 'bookmarks';

  static Future<List<BookmarkItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => BookmarkItem.fromJson(e)).toList();
  }

  static Future<void> add(BookmarkItem item) async {
    final list = await getAll();
    // 중복 방지 (같은 제목)
    if (list.any((b) => b.title == item.title)) return;
    list.insert(0, item);
    await _save(list);
  }

  static Future<void> remove(String title) async {
    final list = await getAll();
    list.removeWhere((b) => b.title == title);
    await _save(list);
  }

  static Future<bool> isBookmarked(String title) async {
    final list = await getAll();
    return list.any((b) => b.title == title);
  }

  static Future<void> _save(List<BookmarkItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
