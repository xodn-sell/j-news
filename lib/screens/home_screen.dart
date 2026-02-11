import 'package:flutter/material.dart';
import 'news_tab.dart';
import 'bookmark_screen.dart';
import 'subscription_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? initialRegion;

  const HomeScreen({super.key, this.initialRegion});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'general';

  final List<Map<String, String>> _categories = [
    {'id': 'general', 'name': '종합', 'icon': '🗞️'},
    {'id': 'tech', 'name': '테크', 'icon': '💻'},
    {'id': 'economy', 'name': '경제', 'icon': '📈'},
    {'id': 'entertainment', 'name': '연예', 'icon': '🎬'},
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
    if (hour < 6) return '고요한 새벽입니다 🌙';
    if (hour < 9) return '좋은 아침입니다 ☀️';
    if (hour < 12) return '오전 브리핑 확인하세요 📰';
    if (hour < 14) return '점심 식사 맛있게 하세요 🍽️';
    if (hour < 18) return '오후의 주요 뉴스입니다 📰';
    if (hour < 21) return '오늘 저녁 브리핑 🌇';
    return '오늘 하루도 수고 많으셨어요 🌙';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Scaffold(
        body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: true,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: theme.colorScheme.surface,
              actions: [
                // 북마크 버튼
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarkScreen()),
                  ),
                  icon: Icon(Icons.bookmark_outline, color: theme.colorScheme.onSurface),
                  tooltip: '북마크',
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
                    label: const Text('PRO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.amber)),
                    style: TextButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 100),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'J-news',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      _greeting(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                background: Container(color: theme.colorScheme.surface),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Column(
                  children: [
                    // 리전 탭
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorColor: theme.colorScheme.primary,
                          indicatorWeight: 3,
                          labelColor: theme.colorScheme.onSurface,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'UNITED STATES'),
                            Tab(text: 'KOREA'),
                          ],
                        ),
                      ),
                    ),
                    // 카테고리 칩
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('${cat['icon']} ${cat['name']}'),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() => _selectedCategory = cat['id']!);
                              },
                              backgroundColor: theme.colorScheme.surface,
                              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              checkmarkColor: theme.colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(
                                color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              NewsTab(region: 'us', category: _selectedCategory, autoLoad: true),
              NewsTab(region: 'kr', category: _selectedCategory, autoLoad: true),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
