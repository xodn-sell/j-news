import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bookmark_service.dart';
import '../theme/jnews_colors.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  List<BookmarkItem> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final list = await BookmarkService.getAll();
    setState(() {
      _bookmarks = list;
      _isLoading = false;
    });
  }

  Future<void> _removeBookmark(BookmarkItem item) async {
    await BookmarkService.remove(item.title);
    await _loadBookmarks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('북마크가 해제되었습니다'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : c.surfaceAlt,
      // 커스텀 헤더 (home/review 스타일 통일 — w900 에디토리얼)
      appBar: AppBar(
        backgroundColor: isDark ? theme.colorScheme.surface : c.surfaceElevated,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '북마크',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: isDark ? c.textPrimary : c.textPrimary,
          ),
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 빈 상태 — jColors 토큰 (다크 대응)
                  Icon(Icons.bookmark_outline, size: 64, color: c.textMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    '저장된 북마크가 없습니다',
                    style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '뉴스 카드의 북마크 아이콘을 눌러 저장하세요',
                    style: TextStyle(color: c.textMuted.withValues(alpha: 0.65), fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookmarks.length,
              itemBuilder: (context, index) {
                final item = _bookmarks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: Key(item.title),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _removeBookmark(item),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        // error 토큰 계열 + 다크 대응, radius 16 (DESIGN.md radius.md)
                        color: c.error.withValues(alpha: isDark ? 0.20 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.delete_outline, color: c.error),
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                // 북마크 아이콘 — warning(amber) → accent 토큰
                                IconButton(
                                  onPressed: () => _removeBookmark(item),
                                  icon: Icon(Icons.bookmark, size: 20, color: c.accent),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            if (item.sourceUrl != null) ...[
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () => _openUrl(item.sourceUrl!),
                                child: Row(
                                  children: [
                                    Icon(Icons.link, size: 14, color: c.accent),
                                    const SizedBox(width: 6),
                                    Text(
                                      item.sourceLabel ?? '원문 보기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
