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
    {'id': 'politics', 'label': '정치', 'icon': Icons.account_balance_rounded},
    {'id': 'economy', 'label': '경제', 'icon': Icons.trending_up},
    {'id': 'tech', 'label': '테크', 'icon': Icons.memory},
    {'id': 'science', 'label': '과학', 'icon': Icons.science_rounded},
    {'id': 'sports', 'label': '스포츠', 'icon': Icons.sports_soccer_rounded},
    {'id': 'health', 'label': '건강', 'icon': Icons.favorite_rounded},
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
            // 상단 헤더 영역 슬림화
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
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
                        const SizedBox(height: 6),
                        Text(
                          _greeting(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 액션 버튼 그룹 슬림화
                  Row(
                    children: [
                      _buildHeaderButton(
                        context, 
                        icon: Icons.bookmark_rounded, 
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BookmarkScreen()),
                        ),
                        theme: theme,
                      ),
                      const SizedBox(width: 4),
                      _buildHeaderButton(
                        context, 
                        icon: Icons.info_rounded, 
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        ),
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 리전 선택기 (US / KR) — 한 줄
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  isScrollable: false,
                  indicator: BoxDecoration(
                    color: isDark ? theme.colorScheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  labelPadding: EdgeInsets.zero,
                  labelColor: isDark ? Colors.white : theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🇺🇸', style: TextStyle(fontSize: 15)), SizedBox(width: 6), Text('US', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5))])),
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🇰🇷', style: TextStyle(fontSize: 15)), SizedBox(width: 6), Text('KR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5))])),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 카테고리 칩 — 한 줄
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat['id'];
                  return _buildCategoryChip(cat, isSelected, theme, isDark);
                },
              ),
            ),

            const SizedBox(height: 10),

            // 뉴스 콘텐츠 영역
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // 카테고리와의 충돌 방지
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

  Widget _buildHeaderButton(BuildContext context, {required IconData icon, required VoidCallback onTap, required ThemeData theme}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(Map<String, dynamic> cat, bool isSelected, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              cat['icon'] as IconData,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 6),
            Text(
              cat['label'] as String,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
