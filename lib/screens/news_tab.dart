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
import '../services/notification_service.dart';

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

      if (widget.category == 'general' && result.items.isNotEmpty) {
        NotificationService.updateNotificationWithNews(
          widget.region,
          result.items.first.title,
        );
      }

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
    final String shareText = '''📰 [J-news 오늘의 브리핑]\n\n$number. ${item.title}\n\n${item.body}\n\n🔗 출처: ${item.sourceLabel} (${item.sourceUrl})''';
    SharePlus.instance.share(ShareParams(text: shareText));
  }

  Future<void> _toggleBookmark(NewsItem item) async {
    final isBookmarked = await BookmarkService.isBookmarked(item.title);
    if (isBookmarked) {
      await BookmarkService.remove(item.title);
    } else {
      await BookmarkService.add(BookmarkItem(
        title: item.title,
        body: item.body,
        sourceLabel: item.sourceLabel,
        sourceUrl: item.sourceUrl,
        savedAt: DateTime.now().toIso8601String(),
      ));
    }
    setState(() {});
  }

  String _scheduleInfo() {
    return widget.region == 'us' ? 'AM 08:00 Update' : 'PM 06:00 Update';
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
            childAnimationBuilder: (widget) => FadeInAnimation(child: widget),
            children: [
              if (_isOfflineData) _buildOfflineBanner(theme),
              _buildCompactMorningHeader(theme, insight),
              const SizedBox(height: 24),
              _buildSectionTitle(theme, '오늘의 뉴스'),
              const SizedBox(height: 12),
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
              const SizedBox(height: 32),
              Center(
                child: Opacity(
                  opacity: 0.3,
                  child: Text(
                    '© J-news · AI-Powered Briefing',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCompactMorningHeader(ThemeData theme, String insight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 12, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(_scheduleInfo(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.primary.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (insight.isNotEmpty) _buildInsightCard(insight, theme),
      ],
    );
  }

  Widget _buildNewsCard(NewsItem item, int number, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? theme.colorScheme.onSurface.withValues(alpha: 0.07)
                : theme.colorScheme.primary.withValues(alpha: 0.06),
          ),
          boxShadow: isDark
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 번호 배지
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // AI 요약 배지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'AI 요약',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: theme.colorScheme.secondary),
                        ),
                      ),
                      const Spacer(),
                      _buildMiniAction(icon: Icons.bookmark_border_rounded, onTap: () => _toggleBookmark(item), theme: theme),
                      const SizedBox(width: 10),
                      _buildMiniAction(icon: Icons.share_rounded, onTap: () => _shareNews(item, number), theme: theme),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.6,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (item.glossary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: item.glossary.map((g) => _buildGlossaryChip(g, theme)).toList()),
                  ],
                ],
              ),
            ),
            if (item.sourceUrl.isNotEmpty)
              InkWell(
                onTap: () => _openUrl(item.sourceUrl),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.04),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 12, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.sourceLabel.isNotEmpty ? item.sourceLabel : '원문 보기',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction({required IconData icon, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
      ),
    );
  }

  Widget _buildInsightCard(String insight, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B2838), const Color(0xFF0D3B6E)]
              : [theme.colorScheme.primary, Color.lerp(theme.colorScheme.primary, const Color(0xFF0066FF), 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 13),
                const SizedBox(width: 5),
                const Text(
                  '1분 핵심 브리핑',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            insight,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14.5,
              height: 1.65,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlossaryChip(GlossaryItem glossary, ThemeData theme) {
    return InkWell(
      onTap: () => _showGlossaryBottomSheet(glossary, theme),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: theme.colorScheme.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
        child: Text(glossary.term, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.secondary)),
      ),
    );
  }

  void _showGlossaryBottomSheet(GlossaryItem glossary, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text(glossary.term, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 12),
            Text(glossary.definition, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.6)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.01),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Container(margin: const EdgeInsets.only(bottom: 12), height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Text('Offline Mode', style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildRawContent(ThemeData theme) => const Center(child: Text('Empty.'));
  Widget _buildEmpty() => const Center(child: Text('No data.'));
  Widget _buildError() => Center(child: FilledButton(onPressed: _fetchNews, child: const Text('Retry')));
}
