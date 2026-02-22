import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import '../models/news_result.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/bookmark_service.dart';
import '../widgets/banner_ad_widget.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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
        'items': result.items.map((i) {
          return {
            'title': i.title,
            'body': i.body,
            'source_label': i.sourceLabel,
            'source_url': i.sourceUrl,
            'glossary': i.glossary.map((g) => {'term': g.term, 'definition': g.definition}).toList(),
          };
        }).toList(),
        'insight': result.insight,
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
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _shareNews(NewsItem item, int number) {
    final String shareText = '''📰 [J-news 오늘의 브리핑]

$number. ${item.title}

${item.body}

🔗 출처: ${item.sourceLabel} (${item.sourceUrl})

📌 더 자세한 뉴스는 'J-news' 앱에서 확인하세요!''';

    SharePlus.instance.share(ShareParams(text: shareText));
  }

  Future<void> _toggleBookmark(NewsItem item) async {
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

  void _reportContent(NewsItem item) {
    final uri = Uri(
      scheme: 'mailto',
      path: 'xowns142857@gmail.com',
      queryParameters: {
        'subject': '[J-news 콘텐츠 신고] ${item.title}',
        'body': '신고 사유:\n\n---\n기사 제목: ${item.title}\n출처: ${item.sourceLabel}\n',
      },
    );
    launchUrl(uri);
  }

  String _scheduleInfo() {
    return widget.region == 'us'
        ? '매일 오전 8시 업데이트 (화~토)'
        : '매일 오후 6시 업데이트 (월~금)';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading && _result == null) return _buildSkeleton(theme);
    if (_error != null) return _buildError();
    if (_result == null) return _buildEmpty();

    final newsItems = _result!.items;
    final insight = _result!.insight;

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

              // 뉴스 리스트 (카드 사이마다 배너 광고 삽입)
              if (newsItems.isNotEmpty)
                ...newsItems.asMap().entries.expand((entry) {
                  final card = _buildNewsCard(entry.value, entry.key + 1, theme);
                  if (entry.key < newsItems.length - 1) {
                    return [card, BannerAdWidget(key: ValueKey('ad_${entry.key}'))];
                  }
                  return [card];
                })
              else
                _buildRawContent(theme),

              // 시사점 섹션
              if (insight.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInsightCard(insight, theme),
              ],

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

  Widget _buildGlossaryChip(GlossaryItem glossary, ThemeData theme) {
    return InkWell(
      onTap: () => _showGlossaryBottomSheet(glossary, theme),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Text(
              glossary.term,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGlossaryBottomSheet(GlossaryItem glossary, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.book, color: theme.colorScheme.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  glossary.term,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              glossary.definition,
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('이해했어요'),
              ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                _scheduleInfo(),
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
          const SizedBox(height: 6),
          Text(
            'AI가 자동 생성한 요약이며 정확성을 보장하지 않습니다',
            style: TextStyle(fontSize: 10, color: theme.colorScheme.primary.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(NewsItem item, int number, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: '뉴스 $number: ${item.title}',
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI 생성 콘텐츠 라벨
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'AI 생성 요약',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$number.',
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
                          onPressed: () => _shareNews(item, number),
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
                    // 용어 설명 칩 추가
                    if (item.glossary.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.glossary.map((g) => _buildGlossaryChip(g, theme)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 출처 + 신고 영역
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    if (item.sourceUrl.isNotEmpty)
                      InkWell(
                        onTap: () => _openUrl(item.sourceUrl),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.sourceLabel.isNotEmpty ? item.sourceLabel : 'Original Article',
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
                    // 신고 버튼
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                        child: TextButton.icon(
                          onPressed: () => _reportContent(item),
                          icon: Icon(Icons.flag_outlined, size: 14, color: Colors.grey[500]),
                          label: Text(
                            '신고',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  ],
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
            colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  '오늘의 AI 핵심 요약',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              insight,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AI의 독립적 분석이며, 사실 확인이 필요합니다. 원문 기사를 반드시 확인해 주세요.',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('데이터 형식이 올바르지 않습니다.'),
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
