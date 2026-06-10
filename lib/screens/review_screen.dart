import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/review_service.dart';
import '../theme/jnews_colors.dart';

// ── 디자인 토큰 (DESIGN.md 준수 — Editorial 톤) ──────────────
// 컬러: context.jColors (ThemeExtension) 경유, 하드코딩 없음
// radius: xl=24 (카드), md=16 (칩·선택), lg=18 (버튼)
// motion: 200ms easeInOut fade만 (컨페티/elasticOut 금지)
const _kCardRadius = 24.0; // radius.xl
const _kChipRadius = 8.0; // radius.sm
const _kBtnRadius = 18.0; // radius.lg
const _kFadeDuration = Duration(milliseconds: 200); // motion.fade

enum _ReviewPhase { loading, empty, card, complete }

/// "오늘의 복습" — SRS due 카드 플래시카드 화면.
/// 앞면=질문(회상 유도) → 탭 → 뒷면=정답+해설 → 기억났어요/다시 볼래요.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  _ReviewPhase _phase = _ReviewPhase.loading;
  List<ReviewCard> _cards = [];
  int _index = 0;
  bool _showBack = false;
  int _reviewedCount = 0;
  ReviewStats? _stats;
  final _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await ReviewService.dueCards();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _phase = cards.isEmpty ? _ReviewPhase.empty : _ReviewPhase.card;
    });
  }

  ReviewCard get _current => _cards[_index];

  void _flip() {
    if (_showBack) return;
    HapticFeedback.lightImpact();
    setState(() => _showBack = true);
  }

  /// 기억났어요=정답 처리(다음 단계), 다시 볼래요=오답 처리(1단계 리셋).
  Future<void> _answer(bool remembered) async {
    await ReviewService.recordResult(_current.question, remembered);
    _reviewedCount++;
    if (_index < _cards.length - 1) {
      setState(() {
        _index++;
        _showBack = false;
      });
    } else {
      await _complete();
    }
  }

  Future<void> _complete() async {
    final stats = await ReviewService.stats();
    _analytics.logEvent(name: 'review_completed', parameters: {
      'count': _reviewedCount,
    });
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _phase = _ReviewPhase.complete;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : c.surfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: _phase == _ReviewPhase.card
            ? Text(
                '${_index + 1} / ${_cards.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.accent.withValues(alpha: 0.80),
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: _kFadeDuration,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _buildPhase(theme, isDark, c),
        ),
      ),
    );
  }

  Widget _buildPhase(ThemeData theme, bool isDark, JNewsColors c) {
    switch (_phase) {
      case _ReviewPhase.loading:
        return const Center(
            key: ValueKey('loading'), child: CircularProgressIndicator());
      case _ReviewPhase.empty:
        return _buildEmpty(theme, isDark, c);
      case _ReviewPhase.card:
        return _buildCard(theme, isDark, c);
      case _ReviewPhase.complete:
        return _buildComplete(theme, isDark, c);
    }
  }

  // ── 빈 상태 ──────────────────────────────────────────────
  Widget _buildEmpty(ThemeData theme, bool isDark, JNewsColors c) {
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    return Padding(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.style_rounded, color: c.accent, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            '오늘 복습할 카드가 없어요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새 브리핑을 읽고 퀴즈를 풀어보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: textPrimary.withValues(alpha: 0.50),
            ),
          ),
        ],
      ),
    );
  }

  // ── 플래시카드 ────────────────────────────────────────────
  Widget _buildCard(ThemeData theme, bool isDark, JNewsColors c) {
    final card = _current;
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    final cardBg =
        isDark ? theme.colorScheme.surfaceContainerHighest : c.surfaceElevated;

    return Padding(
      key: ValueKey('card_$_index'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 출처 기사 칩 (dueDateChip)
          if (card.articleTitle.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(_kChipRadius),
                ),
                child: Text(
                  card.articleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 카드 본체 — 앞=질문(회상 유도), 뒤=정답+해설 (200ms fade)
          Expanded(
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedSwitcher(
                duration: _kFadeDuration,
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: _showBack
                    ? _buildBack(card, isDark, textPrimary, cardBg, c)
                    : _buildFront(card, isDark, textPrimary, cardBg, c),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 뒷면에서만: 기억났어요 / 다시 볼래요
          if (_showBack)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _answer(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            textPrimary.withValues(alpha: 0.70),
                        side: BorderSide(
                            color: textPrimary.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(_kBtnRadius)),
                      ),
                      child: const Text(
                        '다시 볼래요',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _answer(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(_kBtnRadius)),
                      ),
                      child: const Text(
                        '기억났어요',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 앞면 — 질문만 보여주고 회상 유도.
  Widget _buildFront(ReviewCard card, bool isDark, Color textPrimary,
      Color cardBg, JNewsColors c) {
    return Container(
      key: const ValueKey('front'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: isDark
            ? null
            : Border.all(color: c.accent.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            card.question,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.5,
              letterSpacing: -0.4,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '탭해서 정답 확인',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textPrimary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  /// 뒷면 — 정답 + 해설. success 컬러는 정답 표시(state)에만 사용.
  Widget _buildBack(ReviewCard card, bool isDark, Color textPrimary,
      Color cardBg, JNewsColors c) {
    return Container(
      key: const ValueKey('back'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: isDark
            ? null
            : Border.all(color: c.accent.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.question,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5,
                letterSpacing: -0.3,
                color: textPrimary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),

            // 정답 (state 컬러 예외 허용 — success)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: c.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.answerLabel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                      letterSpacing: -0.4,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            if (card.explanation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                card.explanation,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  fontWeight: FontWeight.w500,
                  color: textPrimary.withValues(alpha: 0.70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 완료 화면 ────────────────────────────────────────────
  Widget _buildComplete(ThemeData theme, bool isDark, JNewsColors c) {
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    final cardBg =
        isDark ? theme.colorScheme.surfaceContainerHighest : c.surfaceElevated;
    final stats = _stats;

    return SingleChildScrollView(
      key: const ValueKey('complete'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 디스플레이 타이포 (DESIGN.md display 34px w900)
          Text(
            '복습 완료',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '오늘 복습 $_reviewedCount개 완료',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: c.accent,
            ),
          ),
          const SizedBox(height: 28),

          // 누적 통계 카드
          if (stats != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(_kCardRadius),
                border: isDark
                    ? null
                    : Border.all(color: c.accent.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '누적 학습',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _statRow('🗂️', '총 카드 ${stats.totalCards}개', textPrimary),
                  const SizedBox(height: 12),
                  _statRow('🎓', '마스터 ${stats.masteredCount}개', textPrimary),
                ],
              ),
            ),
          const SizedBox(height: 16),

          Center(
            child: Text(
              '내일 또 만나요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textPrimary.withValues(alpha: 0.40),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 닫기 (메인 CTA 1개 원칙)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBtnRadius)),
              ),
              child: const Text(
                '닫기',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String emoji, String label, Color textPrimary) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}
