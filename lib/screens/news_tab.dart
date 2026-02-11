import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import '../models/news_result.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/bookmark_service.dart';
import 'subscription_screen.dart';

class NewsTab extends StatefulWidget {
  final String region;
  final String category;
  final bool autoLoad;

  const NewsTab({
    super.key,
    required this.region,
    this.category = 'general',
    this.autoLoad = false,
  });

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> with AutomaticKeepAliveClientMixin {
  NewsResult? _result;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineData = false;

  bool _isPro = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProStatus();
    if (widget.autoLoad) {
      _fetchNews();
    }
  }

  @override
  void didUpdateWidget(NewsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category || oldWidget.region != widget.region) {
      _fetchNews();
    }
  }

  Future<void> _loadProStatus() async {
    final isPro = await CacheService.getProStatus();
    if (mounted) setState(() => _isPro = isPro);
  }

  Future<void> _fetchNews() async {
    // 중복 요청 방지
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isOfflineData = false;
    });

    try {
      final result = await ApiService.getNewsSummary(widget.region, category: widget.category);
      if (!mounted) return;
      setState(() => _result = result);

      // 성공 시 캐시 저장
      await CacheService.saveNews(widget.region, widget.category, {
        'summary': result.summary,
        'sources': result.sources.map((s) => {'title': s.title, 'link': s.link}).toList(),
        'updated_at': result.updatedAt,
      });
    } catch (e) {
      if (!mounted) return;
      // 네트워크 실패 시 캐시에서 로드
      final cached = await CacheService.getNews(widget.region, widget.category);
      if (cached != null) {
        setState(() {
          _result = NewsResult.fromJson(cached);
          _isOfflineData = true;
        });
      } else {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareNews(_NewsItem item) {
    final String shareText = '''📰 [J-news 오늘의 브리핑]

${item.number}. ${item.title}

${item.body}

${item.sourceUrl != null ? '🔗 출처: ${item.sourceLabel} (${item.sourceUrl})' : ''}

📌 더 자세한 뉴스는 'J-news' 앱에서 확인하세요!''';

    SharePlus.instance.share(ShareParams(text: shareText));
  }

  Future<void> _toggleBookmark(_NewsItem item) async {
    final isBookmarked = await BookmarkService.isBookmarked(item.title);
    if (isBookmarked) {
      await BookmarkService.remove(item.title);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('북마크가 해제되었습니다'), duration: Duration(seconds: 1)),
        );
      }
    } else {
      await BookmarkService.add(BookmarkItem(
        title: item.title,
        body: item.body,
        sourceLabel: item.sourceLabel,
        sourceUrl: item.sourceUrl,
        savedAt: DateTime.now().toIso8601String(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('북마크에 저장되었습니다'), duration: Duration(seconds: 1)),
        );
      }
    }
    setState(() {}); // 아이콘 상태 갱신
  }

  String _timeAgo() {
    if (_result?.updatedAt != null) {
      final updated = DateTime.parse(_result!.updatedAt!);
      final diff = DateTime.now().difference(updated);
      if (diff.inSeconds < 60) return '방금 전 업데이트됨';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 업데이트됨';
      if (diff.inHours < 24) return '${diff.inHours}시간 전 업데이트됨';
      return '최근 업데이트됨';
    }
    return '실시간 데이터';
  }

  List<_NewsItem> _parseNewsItems(String text) {
    final items = <_NewsItem>[];
    final pattern = RegExp(r'(\d+)\.\s*\*\*(.+?)\*\*');
    final matches = pattern.allMatches(text).toList();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = match.group(2) ?? '';
      final start = match.end;
      final end = (i + 1 < matches.length) ? matches[i + 1].start : text.length;
      var body = text.substring(start, end).trim();

      String? sourceLabel;
      String? sourceUrl;
      final srcPattern = RegExp(r'출처:\s*(.+?)\s*\((https?://[^\s\)]+)\)');
      final srcMatch = srcPattern.firstMatch(body);
      if (srcMatch != null) {
        sourceLabel = srcMatch.group(1)?.trim();
        sourceUrl = srcMatch.group(2)?.trim();
        body = body.replaceAll(srcMatch.group(0)!, '').trim();
      }

      items.add(_NewsItem(
        number: int.tryParse(match.group(1) ?? '') ?? (i + 1),
        title: title,
        body: body,
        sourceLabel: sourceLabel,
        sourceUrl: sourceUrl,
      ));
    }
    return items;
  }

  String? _parseInsight(String text) {
    final pattern = RegExp(r'📌\s*시사점[:\s]*(.+)', dotAll: true);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }

  List<_NewsItem> _filterItems(List<_NewsItem> items) {
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items.where((item) =>
      item.title.toLowerCase().contains(q) ||
      item.body.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading && _result == null) return _buildSkeleton(theme);
    if (_error != null) return _buildError();
    if (_result == null) return _buildEmpty();

    final allItems = _parseNewsItems(_result!.summary);
    final newsItems = _filterItems(allItems);
    final insight = _parseInsight(_result!.summary);

    return RefreshIndicator(
      onRefresh: _fetchNews,
      color: theme.colorScheme.primary,
      child: AnimationLimiter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 500),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              // 오프라인 배너
              if (_isOfflineData)
                _buildOfflineBanner(theme),

              // 업데이트 상단 바
              _buildUpdateHeader(theme),
              const SizedBox(height: 12),

              // 검색 바
              _buildSearchBar(theme),
              const SizedBox(height: 16),

              // 시사점 섹션
              if (insight != null && _searchQuery.isEmpty) ...[
                _buildInsightCard(insight, theme),
                const SizedBox(height: 24),
              ],

              // 뉴스 리스트
              if (newsItems.isNotEmpty)
                ...newsItems.map((item) => _buildNewsCard(item, theme))
              else if (_searchQuery.isNotEmpty)
                _buildNoSearchResult()
              else
                _buildRawContent(theme),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  '© J-news · All contents are generated by AI',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400], letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 10),
          Text(
            '오프라인 모드 · 캐시된 데이터를 표시합니다',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: '뉴스 검색...',
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: _searchQuery.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() => _searchQuery = ''),
            )
          : null,
      ),
    );
  }

  Widget _buildNoSearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              '"$_searchQuery"에 대한 결과가 없습니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            _timeAgo(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          if (_isLoading)
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            )
          else
            Text(
              'Global Sync ON',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(_NewsItem item, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: '뉴스 ${item.number}: ${item.title}',
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.number}.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        // 북마크 버튼
                        FutureBuilder<bool>(
                          future: BookmarkService.isBookmarked(item.title),
                          builder: (context, snapshot) {
                            final isBookmarked = snapshot.data ?? false;
                            return IconButton(
                              onPressed: () => _toggleBookmark(item),
                              icon: Icon(
                                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                size: 20,
                                color: isBookmarked
                                  ? Colors.amber[700]
                                  : theme.colorScheme.primary.withValues(alpha: 0.6),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: '북마크',
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // 공유 버튼
                        IconButton(
                          onPressed: () => _shareNews(item),
                          icon: Icon(
                            Icons.share_outlined,
                            size: 20,
                            color: theme.colorScheme.primary.withValues(alpha: 0.6),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '공유',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.sourceUrl != null)
                InkWell(
                  onTap: () => _openUrl(item.sourceUrl!),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.sourceLabel ?? 'Original Article',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(String insight, ThemeData theme) {
    return Semantics(
      label: '오늘의 AI 핵심 요약',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isPro
              ? [theme.colorScheme.primaryContainer, theme.colorScheme.surface]
              : [Colors.grey.shade200, theme.colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isPro
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isPro ? theme.colorScheme.primary : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  '오늘의 AI 핵심 요약',
                  style: TextStyle(
                    color: _isPro ? theme.colorScheme.primary : Colors.grey[700],
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
                if (!_isPro) ...[
                  const Spacer(),
                  const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (_isPro)
              Text(
                insight,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              )
            else
              Column(
                children: [
                  Text(
                    '${insight.substring(0, insight.length > 30 ? 30 : insight.length)}...',
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.5),
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                        if (result == true) {
                          await _loadProStatus();
                        }
                      },
                      icon: const Icon(Icons.bolt, size: 16),
                      label: const Text('Pro로 잠금 해제하여 전체 읽기'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRawContent(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_result!.summary),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.newspaper, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('뉴스가 아직 없습니다', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _fetchNews, child: const Text('새로고침')),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _error ?? '오류가 발생했습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchNews,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsItem {
  final int number;
  final String title;
  final String body;
  final String? sourceLabel;
  final String? sourceUrl;

  _NewsItem({
    required this.number,
    required this.title,
    required this.body,
    this.sourceLabel,
    this.sourceUrl,
  });
}
