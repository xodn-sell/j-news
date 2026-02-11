import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bookmark_service.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('북마크', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '저장된 북마크가 없습니다',
                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '뉴스 카드의 북마크 아이콘을 눌러 저장하세요',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red),
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
                                IconButton(
                                  onPressed: () => _removeBookmark(item),
                                  icon: Icon(Icons.bookmark, size: 20, color: Colors.amber[700]),
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
                                    Icon(Icons.link, size: 14, color: theme.colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      item.sourceLabel ?? '원문 보기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
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
