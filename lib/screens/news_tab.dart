import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../models/news_result.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/read_service.dart';
import '../services/streak_service.dart';
import '../widgets/native_ad_card.dart';
import '../services/native_ad_service.dart';
import '../services/bookmark_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'chat_sheet.dart';
import 'audio_briefing_screen.dart';
import 'quiz_screen.dart';
import '../services/quiz_service.dart';
import '../services/concept_service.dart';
import '../widgets/concept_progress_card.dart';
import '../theme/jnews_colors.dart';

// ── 토스 디자인 상수 ──
const _kPrimary = Color(0xFF0052CC);
const _kPrimaryLight = Color(0xFFE8F0FF);
const _kBg = Color(0xFFF5F6FA);
const _kCardRadius = 24.0;

/// 다크/라이트 대응 onSurface 알파. BuildContext 경유로 테마 색상 사용.
Color _onSurfaceAlpha(BuildContext context, double a) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: a);
Color _primaryAlpha(double a) => _kPrimary.withValues(alpha: a);


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  NewsTab
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class NewsTab extends StatefulWidget {
  final String region;
  final String category;
  final bool autoLoad;
  final void Function(int current, int total)? onPageChanged;

  const NewsTab({
    super.key,
    required this.region,
    this.category = 'general',
    this.autoLoad = false,
    this.onPageChanged,
  });

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // ── 데이터 ──
  NewsResult? _result;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineData = false;

  // ── 카드 스택 상태 ──
  int _currentIndex = 0;
  bool _showComplete = false;

  // ── 개념 학습 ──
  ConceptProgress? _progress; // 완독 화면 viz용
  final Set<int> _exposedConceptIds = {}; // 이번 세션 노출 기록 dedupe

  // ── 스와이프 힌트 ──
  bool _showSwipeHint = false;
  late AnimationController _hintController;

  // ── 분석 ──
  DateTime? _cardShownAt;
  final _analytics = FirebaseAnalytics.instance;

  // ── 스트릭 ──
  int _streakCount = 0;

  // ── 스와이프 애니메이션 ──
  late AnimationController _swipeController;
  late AnimationController _enterController;
  double _dragX = 0;
  int _swipeDirection = 0;   // -1 = 왼쪽(다음), 1 = 오른쪽(이전)

  // ── 완독 화면 애니메이션 ──
  late AnimationController _completeController;

  static const _swipeThreshold = 60.0;
  // 빠른 swipe 감지: 화면 너비의 50% 이상 / 초 (대략 600~800px/s)
  static const _swipeVelocityThreshold = 800.0;
  // exit: 빠르게 + 짧게 (토스 느낌)
  static const _swipeDuration = Duration(milliseconds: 360);
  static const _snapBackDuration = Duration(milliseconds: 240);
  // ease-out cubic — 시작 빠르고 끝 부드러움
  static const _swipeCurve = Cubic(0.22, 1, 0.36, 1);
  // snap-back: out-back으로 살짝 출렁
  static const _snapCurve = Cubic(0.34, 1.56, 0.64, 1);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(vsync: this, duration: _swipeDuration);
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initSwipeHint();
    NativeAdService.preload(); // 광고 슬롯 도달 전 미리 로드
    if (widget.autoLoad) _fetchNews();
  }

  Future<void> _initSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('swipe_hint_count') ?? 0;
    if (count < 2) {
      await prefs.setInt('swipe_hint_count', count + 1);
      _triggerSwipeHint(seconds: 3);
    }
  }

  void _triggerSwipeHint({int seconds = 2}) {
    if (!mounted || _showSwipeHint) return;
    setState(() => _showSwipeHint = true);
    _hintController.repeat(reverse: true);
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() => _showSwipeHint = false);
        _hintController.stop();
      }
    });
  }

  void _logArticleView(int index, Duration elapsed) {
    if (_result == null) return;
    // 광고 슬롯: 체류시간만 별도 집계
    if (_isAdSlot(index)) {
      _analytics.logEvent(name: 'native_ad_view_duration', parameters: {
        'slot': index,
        'duration_seconds': elapsed.inSeconds,
      });
      return;
    }
    final newsIdx = _newsIndexAt(index);
    if (newsIdx >= _result!.items.length) return; // 인사이트는 제외
    final item = _result!.items[newsIdx];
    _analytics.logEvent(name: 'article_view', parameters: {
      'title': item.title.length > 100 ? item.title.substring(0, 100) : item.title,
      'region': widget.region,
      'index': newsIdx,
      'duration_seconds': elapsed.inSeconds,
    });
    _recordConceptExposure(item.title);
  }

  /// 기사 노출 시 해당 기사 개념을 패시브 기록(세션 내 중복 제외, fire-and-forget).
  void _recordConceptExposure(String articleTitle) {
    final ids = _result?.conceptIdsByTitle[articleTitle];
    if (ids == null || ids.isEmpty) return;
    final fresh = ids.where(_exposedConceptIds.add).toList();
    if (fresh.isEmpty) return;
    ConceptService.recordExposure(fresh); // await 안 함 — UI 비차단
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _enterController.dispose();
    _completeController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NewsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category || oldWidget.region != widget.region) {
      _currentIndex = 0;
      _showComplete = false;
      _fetchNews();
    }
  }

  // ── 데이터 로직 ──
  Future<void> _fetchNews() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _error = null; _isOfflineData = false; _showComplete = false; });
    _exposedConceptIds.clear();
    _progress = null;
    final fetchStart = DateTime.now();
    _analytics.logEvent(name: 'news_load_start', parameters: {
      'region': widget.region,
      'category': widget.category,
    });

    try {
      final result = await ApiService.getNewsSummary(widget.region, category: widget.category);
      if (!mounted) return;
      setState(() => _result = result);
      _cardShownAt = DateTime.now();
      _analytics.logEvent(name: 'news_load_success', parameters: {
        'region': widget.region,
        'category': widget.category,
        'item_count': result.items.length,
        'duration_ms': DateTime.now().difference(fetchStart).inMilliseconds,
      });

      if (widget.category == 'general' && result.items.isNotEmpty) {
        NotificationService.updateNotificationWithNews(result.items.first.title);
      }

      await CacheService.saveNews(widget.region, widget.category, {
        'items': result.items.map((i) => {
          'title': i.title, 'body': i.body,
          'source_label': i.sourceLabel, 'source_url': i.sourceUrl,
          'importance': i.importance,
          'glossary': i.glossary.map((g) => {'term': g.term, 'definition': g.definition}).toList(),
        }).toList(),
        'insight': result.insight.toJson(), 'updated_at': result.updatedAt,
      });
    } catch (e) {
      if (!mounted) return;
      final cached = await CacheService.getNews(widget.region, widget.category);
      if (cached != null) {
        setState(() { _result = NewsResult.fromJson(cached); _isOfflineData = true; });
        _cardShownAt = DateTime.now();
        _analytics.logEvent(name: 'news_load_offline', parameters: {
          'region': widget.region,
          'error': e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString(),
        });
      } else {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        _analytics.logEvent(name: 'news_load_fail', parameters: {
          'region': widget.region,
          'error': e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString(),
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openUrl(String url, String title) async {
    await ReadService.markRead(url, title);
    final host = Uri.tryParse(url)?.host ?? '';
    _analytics.logEvent(name: 'source_url_opened', parameters: {
      'host': host.length > 60 ? host.substring(0, 60) : host,
      'index': _currentIndex,
    });
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _analytics.logEvent(name: 'source_url_fail', parameters: {'host': host});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다'), duration: Duration(seconds: 1)));
    }
  }

  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.briefingnow.app';

  Future<void> _shareText(String title, String body) async {
    _analytics.logEvent(name: 'news_share_tapped', parameters: {
      'title_length': title.length,
      'index': _currentIndex,
    });
    final text = '$title\n\n$body\n\n— J-news\n$_playStoreUrl';
    try {
      await share_plus.SharePlus.instance.share(share_plus.ShareParams(text: text, subject: title));
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('클립보드에 복사했어요'), duration: Duration(seconds: 2)));
      } catch (_) {}
    }
  }

  // ── 카드 네비게이션 ──
  // 광고 슬롯: 뉴스 N개 기준 카드 배치
  //  - N >= 7: [n1, n2, AD, n3, n4, AD, n5, n6, AD, n7, insight] → slots {2, 5, 8}
  //  - N >= 5: [n1, n2, AD, n3, n4, AD, n5, insight] → slots {2, 5}
  //  - N == 4: [n1, n2, AD, n3, n4, insight] → slots {2}
  //  - N < 4: 광고 없음
  List<int> _adSlotIndices() {
    if (_result == null) return const [];
    final n = _result!.items.length;
    if (n >= 7) return const [2, 5, 8];
    if (n >= 5) return const [2, 5];
    if (n == 4) return const [2];
    return const [];
  }

  bool _isAdSlot(int index) => _adSlotIndices().contains(index);

  int _adsBefore(int cardIndex) {
    int count = 0;
    for (final slot in _adSlotIndices()) {
      if (cardIndex > slot) count++;
    }
    return count;
  }

  int _newsIndexAt(int cardIndex) => cardIndex - _adsBefore(cardIndex);

  int _adCount() => _adSlotIndices().length;

  int get _totalCards {
    if (_result == null) return 0;
    return _result!.items.length + _adCount() + (_result!.insight.isEmpty ? 0 : 1);
  }

  /// 완독 화면 진입
  Future<void> _doComplete() async {
    _analytics.logEvent(name: 'news_complete', parameters: {
      'region': widget.region,
      'total_cards': _totalCards,
    });
    final streak = await StreakService.recordCompletion();
    if (!mounted) return;
    setState(() {
      _streakCount = streak;
      _showComplete = true;
    });
    _completeController.forward(from: 0.0);

    // 진척 조회 — viz 갱신(실패해도 완독 화면엔 영향 없음)
    final prog = await ConceptService.getProgress();
    if (mounted && prog != null) setState(() => _progress = prog);
  }

  Future<void> _goNext() async {
    if (_showSwipeHint) {
      setState(() => _showSwipeHint = false);
      _hintController.stop();
    }
    if (_cardShownAt != null) {
      _logArticleView(_currentIndex, DateTime.now().difference(_cardShownAt!));
    }
    _cardShownAt = DateTime.now();
    _analytics.logEvent(name: 'card_swipe', parameters: {
      'direction': 'next',
      'from_index': _currentIndex,
      'total': _totalCards,
    });
    if (_currentIndex >= _totalCards - 1) {
      await _doComplete();
      return;
    }
    setState(() => _currentIndex++);
    widget.onPageChanged?.call(_currentIndex, _totalCards);
    _enterController.forward(from: 0.0);
  }

  void _goPrev() {
    if (_currentIndex <= 0) return;
    if (_cardShownAt != null) {
      _logArticleView(_currentIndex, DateTime.now().difference(_cardShownAt!));
    }
    _cardShownAt = DateTime.now();
    _analytics.logEvent(name: 'card_swipe', parameters: {
      'direction': 'prev',
      'from_index': _currentIndex,
      'total': _totalCards,
    });
    setState(() => _currentIndex--);
    widget.onPageChanged?.call(_currentIndex, _totalCards);
    _enterController.forward(from: 0.0);
  }

  void _goBackFromComplete() {
    _completeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showComplete = false;
          _currentIndex = _totalCards - 1;
        });
        widget.onPageChanged?.call(_currentIndex, _totalCards);
      }
    });
  }

  // ── 스와이프 제스처 핸들러 ──
  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _dragX += d.delta.dx);
  }

  void _onPanEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond.dx;
    final hasVelocity = velocity.abs() > _swipeVelocityThreshold;
    final dragLeft = _dragX < -_swipeThreshold;
    final dragRight = _dragX > _swipeThreshold;

    // 거리 임계값 넘었거나, 충분한 속도 + 같은 방향 드래그
    if (dragLeft || (hasVelocity && velocity < 0 && _dragX < 0)) {
      _swipeDirection = -1;
      _animateSwipe(() => _goNext(), velocity: velocity);
    } else if (dragRight || (hasVelocity && velocity > 0 && _dragX > 0)) {
      _swipeDirection = 1;
      _animateSwipe(() => _goPrev(), velocity: velocity);
    } else {
      _swipeDirection = 0;
      _animateSwipe(null);
    }
  }

  void _animateSwipe(VoidCallback? onComplete, {double velocity = 0}) {
    final startX = _dragX;
    final screenW = MediaQuery.of(context).size.width;
    final isCommit = onComplete != null;
    final endX = isCommit ? (_swipeDirection < 0 ? -screenW * 1.15 : screenW * 1.15) : 0.0;

    // 빠른 velocity → 더 짧게, 느림 → 기본
    final speedFactor = (velocity.abs() / 2000).clamp(0.0, 1.0);
    final commitMs = (360 - 120 * speedFactor).round();
    final duration = isCommit
        ? Duration(milliseconds: commitMs)
        : _snapBackDuration;
    final curve = isCommit ? _swipeCurve : _snapCurve;

    _swipeController.duration = duration;
    _swipeController.reset();
    final anim = Tween<double>(begin: startX, end: endX).animate(
      CurvedAnimation(parent: _swipeController, curve: curve),
    );

    void listener() {
      setState(() => _dragX = anim.value);
    }

    anim.addListener(listener);
    _swipeController.forward().then((_) {
      anim.removeListener(listener);
      setState(() => _dragX = 0);
      onComplete?.call();
    });
  }

  // 드래그 진행률 (0.0 = 정지, 1.0 = 임계값 넘음). 다음 카드 scale/opacity 보간용.
  double get _dragProgress {
    final screenW = MediaQuery.of(context).size.width;
    final norm = (_dragX.abs() / (screenW * 0.5)).clamp(0.0, 1.0);
    return norm;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  BUILD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _result == null) return _buildSkeleton(context, theme);
    if (_error != null) return _buildError(context, theme);
    if (_result == null) return _buildEmpty();

    final total = _totalCards;
    if (total == 0) return _buildEmpty();

    // 부모에게 초기 페이지 알림
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPageChanged?.call(_currentIndex, total);
    });

    if (_showComplete) {
      final completeScaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: _completeController, curve: const Cubic(0.22, 1, 0.36, 1)),
      );
      return GestureDetector(
        onHorizontalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity! > 200) {
            _goBackFromComplete();
          }
        },
        child: FadeTransition(
          opacity: _completeController,
          child: ScaleTransition(
            scale: completeScaleAnim,
            child: _buildCompleteScreen(context, theme, isDark),
          ),
        ),
      );
    }

    final scaffoldBg = isDark ? theme.colorScheme.surface : _kBg;

    return ColoredBox(
      color: scaffoldBg,
      child: Column(
        children: [
          // 카드 스택 영역
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              onVerticalDragEnd: (d) {
                // 상/하 어느 쪽이든 일정 속도 넘으면 힌트
                final v = (d.primaryVelocity ?? 0).abs();
                if (v > 80) _triggerSwipeHint(seconds: 3);
              },
              onVerticalDragUpdate: (d) {
                // 드래그 거리 일정 이상도 힌트 (느린 드래그 대응)
                if (d.delta.dy.abs() > 6 && !_showSwipeHint) {
                  _triggerSwipeHint(seconds: 3);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 세 번째 카드 (가장 뒤, 작고 흐리게) — 드래그 중에만 노출 (정지 시 뒷면 비침 방지)
                  if (_currentIndex + 2 < total && (_dragX != 0 || _dragProgress > 0))
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
                        child: Transform(
                          alignment: Alignment.topCenter,
                          transform: Matrix4.identity()..scale(0.88),
                          child: Opacity(
                            opacity: 0.18,
                            child: _buildCard(_currentIndex + 2, theme, isDark),
                          ),
                        ),
                      ),
                    ),

                  // 두 번째 카드 (peek) — 드래그 중에만 노출 (정지 시 뒷면 비침 방지)
                  if (_currentIndex + 1 < total && (_dragX != 0 || _dragProgress > 0))
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          14 - 4 * _dragProgress,
                          14 - 4 * _dragProgress,
                          14 - 4 * _dragProgress,
                          8 - 2 * _dragProgress,
                        ),
                        child: Transform(
                          alignment: Alignment.topCenter,
                          transform: Matrix4.identity()
                            ..scale(0.94 + 0.05 * _dragProgress),
                          child: Opacity(
                            opacity: (0.50 + 0.45 * _dragProgress).clamp(0.0, 1.0),
                            child: _buildCard(_currentIndex + 1, theme, isDark),
                          ),
                        ),
                      ),
                    ),

                  // 현재 카드 (드래그 따라 이동 + 회전 + 살짝 위로 뜸 + 진입 settle)
                  Positioned.fill(
                    child: Padding(
                      padding: _isAdSlot(_currentIndex)
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(10),
                      child: AnimatedBuilder(
                        animation: _enterController,
                        builder: (_, child) {
                          final isDragging = _dragX != 0;
                          final enterT = isDragging ? 1.0 :
                              CurvedAnimation(parent: _enterController, curve: const Cubic(0.22, 1, 0.36, 1)).value;
                          final enterScale = 0.96 + 0.04 * enterT;
                          final enterOpacity = (0.85 + 0.15 * enterT).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: isDragging ? 1.0 : enterOpacity,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..translate(_dragX, -8.0 * _dragProgress)
                                ..rotateZ(_dragX * 0.0006)
                                ..scale((1.0 - 0.02 * _dragProgress) * (isDragging ? 1.0 : enterScale)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCard(_currentIndex, theme, isDark),
                      ),
                    ),
                  ),

                  // 스와이프 힌트 오버레이 (좌우 화살표)
                  if (_showSwipeHint)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _hintController,
                          builder: (_, child) {
                            final opacity = Tween<double>(begin: 0.12, end: 0.42)
                                .evaluate(CurvedAnimation(parent: _hintController, curve: Curves.easeInOut));
                            return Opacity(opacity: opacity, child: child);
                          },
                          child: Stack(
                            children: [
                              Positioned(
                                left: 20, top: 0, bottom: 0,
                                child: Center(
                                  child: Icon(Icons.chevron_left_rounded, size: 52,
                                      color: isDark ? Colors.white : theme.colorScheme.onSurface),
                                ),
                              ),
                              Positioned(
                                right: 20, top: 0, bottom: 0,
                                child: Center(
                                  child: Icon(Icons.chevron_right_rounded, size: 52,
                                      color: isDark ? Colors.white : theme.colorScheme.onSurface),
                                ),
                              ),
                              Positioned(
                                bottom: 96, left: 0, right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ExcludeSemantics(
                                          child: Icon(
                                            Icons.arrow_back_rounded,
                                            size: 16,
                                            color: isDark ? Theme.of(context).colorScheme.onSurface : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '좌우로 넘겨주세요',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Theme.of(context).colorScheme.onSurface : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ExcludeSemantics(
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: isDark ? Theme.of(context).colorScheme.onSurface : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 오프라인 배지
          if (_isOfflineData)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('Offline', style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  // ── 카드 렌더 분기 ──
  Widget _buildCard(int index, ThemeData theme, bool isDark) {
    // 광고 슬롯
    if (_isAdSlot(index)) {
      return NativeAdCard(
        key: ValueKey('native_ad_$index'),
        isDark: isDark,
        onAdLoaded: () => _analytics.logEvent(name: 'native_ad_loaded', parameters: {'slot': index}),
        onAdFailed: () => _analytics.logEvent(name: 'native_ad_failed', parameters: {'slot': index}),
        onAdImpression: () => _analytics.logEvent(name: 'native_ad_impression', parameters: {'slot': index}),
        onAdClicked: () => _analytics.logEvent(name: 'native_ad_clicked', parameters: {'slot': index}),
        onPrev: index > 0 ? _goPrev : null,
        onNext: _goNext,
      );
    }

    final newsItems = _result!.items;
    final insight = _result!.insight;
    final newsIdx = _newsIndexAt(index);

    if (newsIdx < newsItems.length) {
      final item = newsItems[newsIdx];
      return _NewsCardWidget(
        key: ValueKey('news_${item.sourceUrl}_${item.title}'),
        item: item,
        number: newsIdx + 1,
        isDark: isDark,
        onShare: () => _shareText(item.title, item.body),
        onOpenUrl: () => _openUrl(item.sourceUrl, item.title),
        onGlossaryTap: (g) => _showGlossaryBottomSheet(g, theme),
        onChatTap: () => ChatSheet.show(
          context,
          newsTitle: item.title,
          newsBody: item.body,
          whyMatters: item.whyMatters,
          glossary: item.glossary,
        ),
      );
    } else {
      // 인사이트 카드
      return _InsightCardWidget(
        insight: insight,
        onShare: () => _shareText('오늘의 핵심 인사이트', insight.summary.isNotEmpty ? insight.summary : insight.headline),
        onComplete: _doComplete,
        onAudioTap: _result!.dialogue.isEmpty ? null : () {
          _analytics.logEvent(name: 'audio_briefing_from_insight');
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AudioBriefingScreen(
              dialogue: _result!.dialogue,
              headline: insight.headline.isNotEmpty ? insight.headline : '오늘의 브리핑',
            ),
          ));
        },
      );
    }
  }

  // ── 완독 화면 ──
  Widget _buildCompleteScreen(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [theme.colorScheme.surface, theme.colorScheme.surface],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFEFF4FF), Color(0xFFF5F6FA)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 체크 아이콘 — 더 크고 임팩트 있게
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [_kPrimary.withValues(alpha: 0.25), _kPrimary.withValues(alpha: 0.12)]
                    : [const Color(0xFF2563EB), _kPrimary],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: isDark ? null : [
                BoxShadow(color: _kPrimary.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 24),

          // 스트릭 뱃지
          if (_streakCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    '$_streakCount일 연속 완독',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            '오늘 브리핑 완독!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '오늘의 주요 뉴스를 모두 확인했어요',
            style: TextStyle(fontSize: 15, height: 1.5, color: _onSurfaceAlpha(context, 0.45)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 5, height: 5,
                decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '매일 오전 7시 · 오후 6시 업데이트',
                style: TextStyle(fontSize: 12, color: _onSurfaceAlpha(context, 0.35)),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 학습 진척 카드 — 완독보너스 자리. 누적 배경지식 자산 viz.
          if (_progress != null && !_progress!.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConceptProgressCard(
                progress: _progress!,
                newThisSession: _exposedConceptIds.length,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 퀴즈 CTA — 문항이 있을 때만 표시 (메인 강조)
          Builder(builder: (ctx) {
            final sessionQuiz = QuizService.buildSessionQuiz(_result?.items ?? []);
            if (sessionQuiz.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    _analytics.logEvent(name: 'quiz_started', parameters: {
                      'question_count': sessionQuiz.length,
                    });
                    final items = _result?.items ?? [];
                    final glossaryCount = items.fold<int>(
                        0, (sum, i) => sum + i.glossary.length);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        questions:
                            sessionQuiz.map((e) => e.question).toList(),
                        articleTitles:
                            sessionQuiz.map((e) => e.articleTitle).toList(),
                        newsCount: items.length,
                        glossaryCount: glossaryCount,
                        streakCount: _streakCount,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.quiz_rounded, size: 18),
                  label: const Text('오늘의 퀴즈 풀기',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: isDark ? 0 : 4,
                    shadowColor: _primaryAlpha(0.28),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // 공유 버튼 (보조 — OutlinedButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  final items = _result?.items ?? [];
                  final titles = items.map((i) => '• ${i.title}').join('\n');
                  _shareText('오늘의 J-news 브리핑', '오늘의 주요 뉴스를 모두 읽었어요!\n\n$titles\n\n#J뉴스 #AI뉴스');
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('공유하기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : _kPrimary,
                  side: BorderSide(color: (isDark ? Colors.white : _kPrimary).withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          // 오디오 브리핑 진입 (dialogue가 있을 때만)
          if ((_result?.dialogue ?? []).isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final dialogue = _result!.dialogue;
                    final headline = _result!.insight.headline;
                    _analytics.logEvent(name: 'audio_briefing_from_complete');
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AudioBriefingScreen(
                        dialogue: dialogue,
                        headline: headline.isNotEmpty ? headline : '오늘의 브리핑',
                      ),
                    ));
                  },
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text('오디오로 다시 듣기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : _kPrimary,
                    side: BorderSide(color: (isDark ? Colors.white : _kPrimary).withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 용어 바텀시트 ──
  void _showGlossaryBottomSheet(GlossaryItem glossary, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: _onSurfaceAlpha(context, 0.1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text(glossary.term, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            Text(glossary.definition, style: TextStyle(fontSize: 15, height: 1.6, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))),
          ],
        ),
      ),
    );
  }

  // ── 스켈레톤 ──
  Widget _buildSkeleton(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF2A2D35) : const Color(0xFFEBEBEB),
          highlightColor: isDark ? const Color(0xFF353840) : const Color(0xFFF5F5F5),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(decoration: BoxDecoration(color: context.jColors.surfaceCard, borderRadius: BorderRadius.circular(_kCardRadius))),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'AI가 뉴스를 정리하고 있어요',
              style: TextStyle(
                fontSize: 13,
                color: _onSurfaceAlpha(context, 0.35),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() => const Center(child: Text('뉴스가 없어요.'));
  Widget _buildError(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📡', style: TextStyle(fontSize: 40, color: _onSurfaceAlpha(context, 0.35))),
          const SizedBox(height: 12),
          Text('뉴스를 불러오지 못했어요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _onSurfaceAlpha(context, 0.7))),
          const SizedBox(height: 6),
          Text('인터넷 연결을 확인하고\n다시 시도해주세요', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _onSurfaceAlpha(context, 0.45))),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _fetchNews,
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  뉴스 카드 위젯 (토스 스타일 — 고정 레이아웃, 스크롤 없음)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _NewsCardWidget extends StatefulWidget {
  final NewsItem item;
  final int number;
  final bool isDark;
  final VoidCallback onShare;
  final VoidCallback onOpenUrl;
  final void Function(GlossaryItem) onGlossaryTap;
  final VoidCallback onChatTap;

  const _NewsCardWidget({
    super.key,
    required this.item,
    required this.number,
    required this.isDark,
    required this.onShare,
    required this.onOpenUrl,
    required this.onGlossaryTap,
    required this.onChatTap,
  });

  @override
  State<_NewsCardWidget> createState() => _NewsCardWidgetState();
}

class _NewsCardWidgetState extends State<_NewsCardWidget> {
  bool _expanded = false;
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  @override
  void didUpdateWidget(covariant _NewsCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.title != widget.item.title) {
      setState(() {
        _expanded = false;
        _bookmarked = false;
      });
      _loadBookmark();
    }
  }

  Future<void> _loadBookmark() async {
    final saved = await BookmarkService.isBookmarked(widget.item.title);
    if (mounted) setState(() => _bookmarked = saved);
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    final item = widget.item;
    if (_bookmarked) {
      await BookmarkService.remove(item.title);
      if (!mounted) return;
      setState(() => _bookmarked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('북마크 해제'),
          duration: Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await BookmarkService.add(BookmarkItem(
        title: item.title,
        body: item.body,
        sourceLabel: item.sourceLabel,
        sourceUrl: item.sourceUrl,
        savedAt: DateTime.now().toIso8601String(),
      ));
      if (!mounted) return;
      setState(() => _bookmarked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔖 북마크 저장'),
          duration: Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final number = widget.number;
    final isDark = widget.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.jColors.surfaceCard,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: isDark ? null : const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 카드 내부 (padding 28 24 16) ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 번호배지 + 중요도 + 공유
                  Row(
                    children: [
                      // 번호 배지 (32x32, E8F0FF bg, radius 10)
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? _primaryAlpha(0.18) : _kPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('$number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? _kPrimary.withValues(alpha: 0.9) : _kPrimary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 중요도 배지 (importance 4 이상만 표시)
                      if ((item.importance ?? 0) >= 5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('🔥', style: TextStyle(fontSize: 11)),
                              SizedBox(width: 3),
                              Text('오늘 핵심', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFF3B30))),
                            ],
                          ),
                        )
                      else if ((item.importance ?? 0) == 4)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primaryAlpha(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up_rounded, size: 12, color: _kPrimary),
                              const SizedBox(width: 3),
                              const Text('주목', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kPrimary)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // 북마크 버튼 (48dp 히트 영역)
                      Semantics(
                        label: _bookmarked ? '북마크 해제' : '북마크',
                        button: true,
                        child: GestureDetector(
                          onTap: _toggleBookmark,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 40, height: 40,
                            child: Center(
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: _bookmarked
                                      ? _primaryAlpha(isDark ? 0.22 : 0.10)
                                      : _onSurfaceAlpha(context, isDark ? 0.08 : 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                  size: 16,
                                  color: _bookmarked ? _kPrimary : _onSurfaceAlpha(context, 0.45),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 공유 버튼 (48dp 히트 영역)
                      Semantics(
                        label: '공유',
                        button: true,
                        child: GestureDetector(
                          onTap: widget.onShare,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 40,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _onSurfaceAlpha(context, isDark ? 0.08 : 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.ios_share_rounded, size: 13, color: _onSurfaceAlpha(context, 0.4)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '공유',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _onSurfaceAlpha(context, 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 제목 (20px w900, letterSpacing -0.6, maxLines 4)
                  Text(
                    item.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                      letterSpacing: -0.6,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 본문 (15px, 1.7, 70%, maxLines 6 + fade + 더 보기)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Text(
                                item.body,
                                maxLines: _expanded ? null : 6,
                                overflow: _expanded ? TextOverflow.visible : TextOverflow.clip,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1.7,
                                  color: isDark ? Colors.white.withValues(alpha: 0.7) : _onSurfaceAlpha(context, 0.70),
                                ),
                              ),
                              if (!_expanded)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: ShaderMask(
                                    shaderCallback: (rect) => const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.white, Colors.transparent],
                                      stops: [0.5, 1.0],
                                    ).createShader(rect),
                                    blendMode: BlendMode.dstIn,
                                    child: Container(
                                      height: 40,
                                      color: context.jColors.surfaceCard,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_expanded || item.body.length >= 200)
                          GestureDetector(
                            onTap: () => setState(() => _expanded = !_expanded),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: 32,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _expanded ? '접기' : '더 보기',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0052CC),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── 용어 칩 (본문 바로 아래) ──
                  if (item.glossary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: item.glossary.map((g) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Semantics(
                              label: '용어: ${g.term}',
                              button: true,
                              child: GestureDetector(
                                onTap: () => widget.onGlossaryTap(g),
                                behavior: HitTestBehavior.opaque,
                                child: SizedBox(
                                  height: 36,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _primaryAlpha(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _primaryAlpha(0.15), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.info_outline_rounded, size: 11, color: _primaryAlpha(0.7)),
                                          const SizedBox(width: 4),
                                          Text(g.term, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── AI랑 토론 CTA ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: widget.onChatTap,
                icon: const Icon(Icons.forum_rounded, size: 16),
                label: const Text(
                  'AI 튜터에게 물어보기',
                  // height 명시 + 패딩 제거 — 고정 높이 버튼에서 한글 글리프 하단 클리핑 방지
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.2),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.isDark ? _primaryAlpha(0.22) : _kPrimaryLight,
                  foregroundColor: _kPrimary,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          // ── AI 요약 배지 + 면책 안내 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 11, color: _kPrimary),
                      const SizedBox(width: 4),
                      const Text(
                        'AI가 요약했어요',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 요약 · 원문을 확인하세요',
                  style: TextStyle(fontSize: 10, color: _onSurfaceAlpha(context, 0.35)),
                ),
              ],
            ),
          ),

          // ── 출처 (토스 스타일) ──
          if (item.sourceUrl.isNotEmpty)
            GestureDetector(
              onTap: widget.onOpenUrl,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _primaryAlpha(isDark ? 0.08 : 0.06),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_kCardRadius)),
                  border: Border(top: BorderSide(color: _primaryAlpha(0.12), width: 1)),
                ),
                child: Row(
                  children: [
                    // 아이콘 (28x28, radius 8)
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: _primaryAlpha(0.12), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.open_in_new_rounded, size: 14, color: _kPrimary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('원문 출처', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _onSurfaceAlpha(context, 0.45))),
                          if (item.sourceLabel.isNotEmpty)
                            Text(item.sourceLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kPrimary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: _primaryAlpha(0.5)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  인사이트 카드 (토스 스타일)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _InsightCardWidget extends StatefulWidget {
  final InsightData insight;
  final VoidCallback onShare;
  final VoidCallback? onComplete;
  final VoidCallback? onAudioTap;

  const _InsightCardWidget({
    required this.insight,
    required this.onShare,
    this.onComplete,
    this.onAudioTap,
  });

  @override
  State<_InsightCardWidget> createState() => _InsightCardWidgetState();
}

class _InsightCardWidgetState extends State<_InsightCardWidget> {

  // mood별 색상/이모지
  static const _moodConfig = {
    'optimistic': (emoji: '📈', label: '긍정적', color: Color(0xFF34C759)),
    'cautious':   (emoji: '⚠️', label: '주의',   color: Color(0xFFFF9500)),
    'alarming':   (emoji: '🚨', label: '경계',   color: Color(0xFFFF3B30)),
    'neutral':    (emoji: '➖', label: '중립',   color: Color(0xFFAAAAAA)),
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1628), Color(0xFF0D2060), Color(0xFF1B3FA6)],
            stops: [0.0, 0.45, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // 배경 장식
            Positioned(top: -50, right: -50, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.03)))),
            Positioned(bottom: -70, left: -30, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1B3FA6).withValues(alpha: 0.25)))),

            _buildUnlockedContent(),

          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedContent() {
    final insight = widget.insight;
    final mood = _moodConfig[insight.mood] ?? _moodConfig['neutral']!;
    final isStructured = insight.isStructured;

    return Positioned.fill(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 뱃지 행
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text('AI 심층 분석', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    ],
                  ),
                ),
                if (isStructured) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: mood.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: mood.color.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      '${mood.emoji} ${mood.label}',
                      style: TextStyle(color: mood.color, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const Spacer(),
                // 공유 버튼 (다른 카드와 동일 스타일)
                GestureDetector(
                  onTap: widget.onShare,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ios_share_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text('공유', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 헤드라인
            if (isStructured && insight.headline.isNotEmpty) ...[
              Text(
                insight.headline,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.25, letterSpacing: -0.6),
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 14),
            ] else ...[
              const Text('AI가 분석한\n오늘의 핵심', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.3, letterSpacing: -0.5)),
              const SizedBox(height: 14),
            ],

            // 핵심 포인트
            if (isStructured && insight.points.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.push_pin_rounded, color: Color(0xFF7EB3FF), size: 13),
                  const SizedBox(width: 5),
                  Text('핵심 포인트', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ],
              ),
              const SizedBox(height: 10),
              ...insight.points.asMap().entries.map((e) {
                final idx = e.key;
                final point = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: _kPrimary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(point, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
              const SizedBox(height: 12),
            ],

            // 배경/맥락 (summary)
            if (insight.summary.isNotEmpty) ...[
              if (isStructured) Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF7EB3FF), size: 12),
                  const SizedBox(width: 5),
                  Text('배경', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ],
              ),
              if (isStructured) const SizedBox(height: 8),
              Text(insight.summary, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14, height: 1.7, fontWeight: FontWeight.w400)),
            ],

            // 전망
            if (isStructured && insight.outlook.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔭', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('전망', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(insight.outlook, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13, height: 1.55, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 오디오 브리핑 진입 (dialogue가 있을 때만)
            if (widget.onAudioTap != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: widget.onAudioTap,
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text(
                    '오디오로 듣기 (지음 & 소나)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
