import 'package:flutter/material.dart';
import 'news_tab.dart';
import 'bookmark_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? initialRegion;

  const HomeScreen({super.key, this.initialRegion});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'general';

  final List<Map<String, dynamic>> _categories = [
    {'id': 'general', 'label': '종합', 'icon': Icons.public},
    {'id': 'tech', 'label': '테크', 'icon': Icons.memory},
    {'id': 'economy', 'label': '경제', 'icon': Icons.trending_up},
    {'id': 'entertainment', 'label': '연예', 'icon': Icons.movie_outlined},
  ];

  @override
  void initState() {
    super.initState();
    int initialTab;
    if (widget.initialRegion == 'kr') {
      initialTab = 1;
    } else if (widget.initialRegion == 'us') {
      initialTab = 0;
    } else {
      final hour = DateTime.now().hour;
      initialTab = (hour >= 18 && hour < 24) ? 1 : 0;
    }
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialTab);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '고요한 새벽이에요';
    if (hour < 9) return '좋은 아침이에요';
    if (hour < 12) return '오전 브리핑 준비됐어요';
    if (hour < 14) return '점심 시간 브리핑';
    if (hour < 18) return '오후의 주요 뉴스';
    if (hour < 21) return '저녁 브리핑 시간';
    return '오늘의 마지막 브리핑';
  }

  String _subGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'AI가 밤사이 세상 소식을 정리했어요';
    if (hour < 12) return 'AI가 오늘의 핵심 뉴스를 정리했어요';
    if (hour < 18) return 'AI가 실시간 뉴스를 분석하고 있어요';
    return 'AI가 하루를 마무리하는 브리핑을 준비했어요';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 헤더 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'J-NEWS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34C759),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _greeting(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subGreeting(),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 액션 버튼들
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BookmarkScreen()),
                    ),
                    icon: const Icon(Icons.bookmark_outline_rounded, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: '북마크',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    icon: const Icon(Icons.info_outline_rounded, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: '앱 정보',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 리전 탭 (US / KOREA)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                  tabs: const [
                    Tab(text: '🇺🇸'),
                    Tab(text: '🇰🇷'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 카테고리 칩
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 4),

            // 뉴스 콘텐츠
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  NewsTab(key: ValueKey('us_$_selectedCategory'), region: 'us', category: _selectedCategory, autoLoad: true),
                  NewsTab(key: ValueKey('kr_$_selectedCategory'), region: 'kr', category: _selectedCategory, autoLoad: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
