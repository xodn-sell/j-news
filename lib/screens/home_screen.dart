import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'news_tab.dart';
import 'settings_screen.dart';
import 'bookmark_screen.dart';
import 'review_screen.dart';
import '../services/news_session.dart';
import '../services/review_service.dart';
import '../theme/jnews_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  int _totalPages = 0;
  int _reviewDueCount = 0; // 오늘 복습할 SRS 카드 수 (헤더 배지)
  int _pulseRepeatCount = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  Timer? _countdownTimer;

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.month}월 ${now.day}일';
  }

  String _sessionTitle() => '${NewsSession.currentSessionLabel()} 브리핑';

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'home_shown');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // 3회 펄스 후 정지 — 상시 repaint 방지
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseRepeatCount++;
        if (_pulseRepeatCount < 3) {
          _pulseController.reverse();
        }
      } else if (status == AnimationStatus.dismissed && _pulseRepeatCount < 3) {
        _pulseController.forward();
      }
    });
    _pulseController.forward();

    // 세션 카운트다운: 30초마다 라벨 갱신 (다음 세션 시작 시 자동 전환)
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    _refreshReviewDue();
  }

  /// 오늘 due 카드 수 갱신 (헤더 배지).
  Future<void> _refreshReviewDue() async {
    final stats = await ReviewService.stats();
    if (mounted) setState(() => _reviewDueCount = stats.dueToday);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int current, int total) {
    if (!mounted) return;
    setState(() {
      _currentPage = current;
      _totalPages = total;
    });
  }

  void _openSettings() {
    FirebaseAnalytics.instance.logEvent(name: 'settings_opened');
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openBookmarks() {
    FirebaseAnalytics.instance.logEvent(name: 'bookmarks_opened');
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarkScreen()));
  }

  Future<void> _openReview() async {
    FirebaseAnalytics.instance.logEvent(name: 'review_opened');
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ReviewScreen()));
    _refreshReviewDue(); // 복습 후 배지 갱신
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;
    final scaffoldBg = isDark ? theme.colorScheme.surface : c.surfaceAlt;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 전체 (브랜드 행 + 진행바)
            Container(
              decoration: BoxDecoration(
                // DESIGN.md §8 — editorial 화면 그라디언트 금지, 단색
                color: isDark ? theme.colorScheme.surface : c.surfaceElevated,
                boxShadow: isDark ? null : [
                  BoxShadow(color: c.textPrimary.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 톱 브랜드 행 — editorial 절제 (상단 여유: 아이콘이 상태바에 붙지 않게)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.only(top: 6),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 왼쪽: J-NEWS 워드마크 + pulse
                        Positioned(
                          left: 20,
                          child: Row(
                            children: [
                              Text(
                                'J-NEWS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: (isDark ? Colors.white : const Color(0xFF0D1117)).withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 6),
                              RepaintBoundary(
                                child: AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (_, __) {
                                    final v = _pulseAnim.value;
                                    return Container(
                                      width: 5, height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: c.success,
                                        boxShadow: [
                                          BoxShadow(
                                            color: c.success.withValues(alpha: (1.0 - v) * 0.4),
                                            blurRadius: v * 5,
                                            spreadRadius: v * 4,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 오른쪽: 북마크 + 설정
                        Positioned(
                          right: 12,
                          child: Row(
                            children: [
                              _HeaderIconButton(icon: Icons.style_rounded, onTap: _openReview, theme: theme, badgeCount: _reviewDueCount, tooltip: '복습'),
                              const SizedBox(width: 6),
                              _HeaderIconButton(icon: Icons.bookmark_outline_rounded, onTap: _openBookmarks, theme: theme, tooltip: '북마크'),
                              const SizedBox(width: 6),
                              _HeaderIconButton(icon: Icons.tune_rounded, onTap: _openSettings, theme: theme, tooltip: '설정'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 에디토리얼 디스플레이: 세션 타이틀 (잡지 헤드라인) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 메타: 날짜
                              Text(
                                _todayLabel(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF0052CC).withValues(alpha: isDark ? 0.85 : 0.75),
                                ),
                              ),
                              const SizedBox(height: 2),
                              // 디스플레이: 세션 브리핑
                              Text(
                                _sessionTitle(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  height: 1.15,
                                  color: isDark ? Colors.white : const Color(0xFF0D1117),
                                ),
                              ),
                              const SizedBox(height: 3),
                              // 카운트다운: 다음 세션까지
                              Text(
                                '다음 ${NewsSession.nextSessionLabel()} 브리핑까지 ${NewsSession.nextSessionCountdown()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  color: (isDark ? Colors.white : const Color(0xFF0D1117)).withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 우측 메타: AI 큐레이션 라벨
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: (isDark ? Colors.white : const Color(0xFF0D1117)).withValues(alpha: 0.15),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI 큐레이션',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: (isDark ? Colors.white : const Color(0xFF0D1117)).withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 진행 바 (3px)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0.0;
                      return Stack(
                        children: [
                          Container(
                            height: 3,
                            width: constraints.maxWidth,
                            color: c.textPrimary.withValues(alpha: isDark ? 0.12 : 0.06),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                            height: 3,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(2), bottomRight: Radius.circular(2)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // 뉴스 콘텐츠
            Expanded(
              child: NewsTab(
                region: 'world',
                category: 'general',
                autoLoad: true,
                onPageChanged: _onPageChanged,
              ),
            ),

            // ── SRS 복습 배너 (due > 0, 맨 아래) — 단 AI 심층분석(마지막 카드)에선 숨김 ──
            if (_reviewDueCount > 0 &&
                _totalPages > 0 &&
                _currentPage < _totalPages - 1)
              _ReviewBanner(dueCount: _reviewDueCount, onTap: _openReview),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final int badgeCount; // 0이면 배지 숨김 (복습 due 카운트)
  final String? tooltip;

  const _HeaderIconButton({required this.icon, required this.onTap, required this.theme, this.badgeCount = 0, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final c = context.jColors;
    final label = tooltip ?? '';
    final semanticLabel = badgeCount > 0 ? '$label, $badgeCount개' : label;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          // 히트 영역 44 — 시각 컨테이너(36)는 기존 그대로
          child: SizedBox(
            width: 44, height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                // due 카운트 배지 — 시각 컨테이너 모서리 밖 (아이콘과 겹침 방지)
                if (badgeCount > 0)
                  Positioned(
                    top: 2, right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: c.error,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SRS 복습 배너 — due > 0 일 때만 홈 헤더 아래 노출 ──
class _ReviewBanner extends StatelessWidget {
  final int dueCount;
  final VoidCallback onTap;

  const _ReviewBanner({required this.dueCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.jColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '오늘 복습할 카드 $dueCount개. 복습 시작하기',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Material(
          color: isDark ? c.accent.withValues(alpha: 0.14) : c.surfaceTint,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.style_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '오늘 복습할 카드 $dueCount개',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: c.accent,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: c.accent.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
