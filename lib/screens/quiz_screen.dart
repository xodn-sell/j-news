import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../models/news_result.dart';
import '../services/quiz_service.dart';
import '../services/review_service.dart';
import '../services/concept_service.dart';
import '../theme/jnews_colors.dart';
import '../widgets/achievement_summary.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// ── 디자인 토큰 (DESIGN.md 준수) ─────────────────────────────
// 컬러: context.jColors (ThemeExtension) 경유, 하드코딩 없음
// radius xl=24, md=16, lg=18 (DESIGN.md radius)
// motion: 200ms easeInOut (DESIGN.md motion.fade — editorial tone)

const _kCardRadius = 24.0;  // radius.xl
const _kChoiceRadius = 16.0; // radius.md
const _kBtnRadius = 18.0;    // radius.lg

const _kFeedbackDuration = Duration(milliseconds: 200); // motion.fade

enum _QuizPhase { intro, question, result }

class QuizScreen extends StatefulWidget {
  final List<QuizQuestion> questions;

  /// questions와 같은 길이의 출처 기사 제목 (복습 카드 등록용).
  final List<String> articleTitles;
  final int newsCount;
  final int glossaryCount;
  final int streakCount;

  const QuizScreen({
    super.key,
    required this.questions,
    this.articleTitles = const [],
    required this.newsCount,
    required this.glossaryCount,
    required this.streakCount,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  _QuizPhase _phase = _QuizPhase.intro;
  int _qIndex = 0;
  int? _selectedOption;     // 선택됨(미확정)
  bool _revealed = false;   // 정답 공개
  int _correctCount = 0;
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnim;
  final _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: _kFeedbackDuration,
    );
    _feedbackAnim = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeInOut,
    );
    _analytics.logEvent(name: 'quiz_started', parameters: {
      'question_count': widget.questions.length,
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  QuizQuestion get _currentQ => widget.questions[_qIndex];

  void _selectOption(int idx) {
    if (_revealed) return;
    setState(() => _selectedOption = idx);
  }

  Future<void> _reveal() async {
    if (_selectedOption == null || _revealed) return;
    final q = _currentQ;
    final isCorrect = _selectedOption == q.answerIndex;
    if (isCorrect) _correctCount++;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
    _feedbackController.forward(from: 0.0);

    // 출처 기사 제목 (articleTitles 미전달 시 빈 문자열)
    final articleTitle = _qIndex < widget.articleTitles.length
        ? widget.articleTitles[_qIndex]
        : '';
    await QuizService.recordAttempt(
      question: q.question,
      articleTitle: articleTitle,
      correct: isCorrect,
    );
    // 푼 문제를 SRS 복습 카드로 등록 (stage 1 → 내일 due)
    await ReviewService.addCard(q, articleTitle);
    // 정밀 개념 SRS — 문항이 묻는 개념을 서버에 승급/리셋 (fire-and-forget)
    for (final cid in q.conceptIds) {
      ConceptService.recordReview(cid, isCorrect);
    }
    _analytics.logEvent(name: 'quiz_attempted', parameters: {
      'question_index': _qIndex,
      'correct': isCorrect,
    });
  }

  void _nextQuestion() {
    if (_qIndex < widget.questions.length - 1) {
      setState(() {
        _qIndex++;
        _selectedOption = null;
        _revealed = false;
        _feedbackController.reset();
      });
    } else {
      _analytics.logEvent(name: 'quiz_session_complete', parameters: {
        'correct_count': _correctCount,
        'total': widget.questions.length,
      });
      setState(() => _phase = _QuizPhase.result);
    }
  }

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.briefingnow.app';

  Future<void> _share() async {
    final total = widget.questions.length;
    final text =
        '오늘 J-news 퀴즈에서 $_correctCount/$total 맞혔어요!\n'
        '뉴스 ${widget.newsCount}개 읽고 내용 확인까지.\n\n'
        '— J-news\n$_playStoreUrl';
    try {
      await share_plus.SharePlus.instance.share(
        share_plus.ShareParams(text: text, subject: '오늘의 퀴즈 결과'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('클립보드에 복사했어요'),
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;

    return Scaffold(
      backgroundColor:
          isDark ? theme.colorScheme.surface : c.surfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: _phase == _QuizPhase.question
            ? _buildProgressDots(isDark, c)
            : null,
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: _kFeedbackDuration,
          child: _buildPhase(theme, isDark, c),
        ),
      ),
    );
  }

  Widget _buildPhase(ThemeData theme, bool isDark, JNewsColors c) {
    switch (_phase) {
      case _QuizPhase.intro:
        return _buildIntro(theme, isDark, c);
      case _QuizPhase.question:
        return _buildQuestion(theme, isDark, c);
      case _QuizPhase.result:
        return _buildResult(theme, isDark, c);
    }
  }

  // ── 진행 도트 ────────────────────────────────────────────
  Widget _buildProgressDots(bool isDark, JNewsColors c) {
    final total = widget.questions.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final done = i < _qIndex;
        final current = i == _qIndex;
        return AnimatedContainer(
          duration: _kFeedbackDuration,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            // accent 토큰 경유: 다크에서는 dark.accent(#4A90D9), 라이트에서는 #0052CC
            color: done
                ? c.accent
                : current
                    ? c.accent
                    : c.accent.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── A. 인트로 ────────────────────────────────────────────
  Widget _buildIntro(ThemeData theme, bool isDark, JNewsColors c) {
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    return Padding(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.quiz_rounded,
                color: c.accent, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            '오늘 뉴스 확인 퀴즈',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '방금 읽은 내용 ${widget.questions.length}문제',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textPrimary.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () =>
                  setState(() => _phase = _QuizPhase.question),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBtnRadius)),
              ),
              child: const Text(
                '시작하기',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── B. 문제 카드 ─────────────────────────────────────────
  Widget _buildQuestion(ThemeData theme, bool isDark, JNewsColors c) {
    final q = _currentQ;
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : c.surfaceElevated;

    return SingleChildScrollView(
      key: ValueKey('q_$_qIndex'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 문제 번호 + 유형 배지
          Row(
            children: [
              Text(
                '${_qIndex + 1} / ${widget.questions.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  // accent 토큰 경유: 다크 #4A90D9, 라이트 #0052CC — WCAG AA 충족
                  color: c.accent.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  q.type == 'ox' ? 'O/X' : '4지선다',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 질문 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(_kCardRadius),
              border: isDark
                  ? null
                  : Border.all(
                      color: c.accent.withValues(alpha: 0.08)),
            ),
            child: Text(
              q.question,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.5,
                letterSpacing: -0.4,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 선택지 — OX는 전용 좌우 O/X 선택 UI, 4지선다는 세로 리스트
          if (q.type == 'ox')
            _buildOxSelector(q, isDark, textPrimary, c)
          else
            ...List.generate(q.options.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildChoice(
                    i, q.options[i], q.answerIndex, isDark, textPrimary, c),
              );
            }),

          const SizedBox(height: 8),

          // 정답 확인 버튼
          if (!_revealed)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _selectedOption != null ? _reveal : null,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  disabledBackgroundColor:
                      c.accent.withValues(alpha: 0.30),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_kBtnRadius)),
                ),
                child: const Text(
                  '정답 확인',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),

          // 해설 패널 (slideUp 200ms)
          if (_revealed) _buildFeedbackPanel(q, isDark, textPrimary, c),
        ],
      ),
    );
  }

  Widget _buildChoice(int idx, String label, int answerIdx,
      bool isDark, Color textPrimary, JNewsColors c) {
    // 상태 계산
    final isSelected = _selectedOption == idx;
    final isAnswer = idx == answerIdx;

    Color borderColor;
    Color bgColor;
    Widget? trailingIcon;

    if (_revealed) {
      if (isAnswer) {
        // 정답 — state 컬러 예외 허용 (success)
        borderColor = c.success;
        bgColor = c.success.withValues(alpha: 0.08);
        trailingIcon = Icon(Icons.check_circle_rounded,
            color: c.success, size: 20);
      } else if (isSelected) {
        // 내가 고른 오답 — state 컬러 예외 허용 (error)
        borderColor = c.error;
        bgColor = c.error.withValues(alpha: 0.08);
        trailingIcon = Icon(Icons.cancel_rounded,
            color: c.error, size: 20);
      } else {
        borderColor = Colors.transparent;
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : c.surfaceAlt;
      }
    } else if (isSelected) {
      // 선택됨(미확정)
      borderColor = c.accent;
      bgColor = c.accent.withValues(alpha: 0.06);
    } else {
      borderColor = Colors.transparent;
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : c.surfaceAlt;
    }

    return GestureDetector(
      onTap: () => _selectOption(idx),
      child: AnimatedContainer(
        duration: _kFeedbackDuration,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_kChoiceRadius),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
            if (trailingIcon != null) trailingIcon,
          ],
        ),
      ),
    );
  }

  // ── OX 전용 선택 UI — 좌우 큰 O / X 버튼 ──
  Widget _buildOxSelector(
      QuizQuestion q, bool isDark, Color textPrimary, JNewsColors c) {
    // 데이터 옵션 순서(보통 ['O','X'])대로 idx 매핑. idx0=O, idx1=X.
    return Row(
      children: [
        Expanded(child: _buildOxTile(0, true, q, isDark, textPrimary, c)),
        const SizedBox(width: 12),
        Expanded(child: _buildOxTile(1, false, q, isDark, textPrimary, c)),
      ],
    );
  }

  Widget _buildOxTile(int idx, bool isO, QuizQuestion q, bool isDark,
      Color textPrimary, JNewsColors c) {
    if (idx >= q.options.length) return const SizedBox.shrink();
    final isSelected = _selectedOption == idx;
    final isAnswer = idx == q.answerIndex;

    Color borderColor;
    Color bgColor;
    Color symbolColor;

    if (_revealed) {
      if (isAnswer) {
        borderColor = c.success;
        bgColor = c.success.withValues(alpha: 0.10);
        symbolColor = c.success;
      } else if (isSelected) {
        borderColor = c.error;
        bgColor = c.error.withValues(alpha: 0.10);
        symbolColor = c.error;
      } else {
        borderColor = Colors.transparent;
        bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : c.surfaceAlt;
        symbolColor = textPrimary.withValues(alpha: 0.30);
      }
    } else if (isSelected) {
      borderColor = c.accent;
      bgColor = c.accent.withValues(alpha: 0.08);
      symbolColor = c.accent;
    } else {
      borderColor = Colors.transparent;
      bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : c.surfaceAlt;
      symbolColor = textPrimary.withValues(alpha: 0.55);
    }

    return GestureDetector(
      onTap: () => _selectOption(idx),
      child: AnimatedContainer(
        duration: _kFeedbackDuration,
        height: 120,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_kChoiceRadius),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Icon(
            isO ? Icons.radio_button_unchecked_rounded : Icons.close_rounded,
            size: 52,
            color: symbolColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackPanel(
      QuizQuestion q, bool isDark, Color textPrimary, JNewsColors c) {
    final isCorrect = _selectedOption == q.answerIndex;
    // state 컬러 예외 허용 (success/error)
    final stateColor = isCorrect ? c.success : c.error;
    final label = isCorrect ? '정답이에요' : '아쉬워요';
    final icon = isCorrect ? '✅' : '❌';
    final isLast = _qIndex >= widget.questions.length - 1;

    return FadeTransition(
      opacity: _feedbackAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_feedbackAnim),
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(_kCardRadius),
            border:
                Border.all(color: stateColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: stateColor,
                    ),
                  ),
                ],
              ),
              if (q.explanation.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  q.explanation,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: textPrimary.withValues(alpha: 0.70),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _nextQuestion,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_kChoiceRadius)),
                  ),
                  child: Text(
                    isLast ? '결과 보기' : '다음 문제 →',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── C. 결과 화면 — AchievementSummary 공용 위젯 사용 ─────
  Widget _buildResult(ThemeData theme, bool isDark, JNewsColors c) {
    final total = widget.questions.length;
    final allCorrect = _correctCount == total;
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    final copyLine = allCorrect
        ? '모두 맞혔어요!'
        : '$_correctCount개 맞혔어요';

    // 통계 행 구성 (null 조건부)
    final stats = <(String, String)>[
      ('📰', '뉴스 ${widget.newsCount}개 읽음'),
      ('🧠', '퀴즈 $_correctCount개 맞힘'),
      if (widget.glossaryCount > 0) ('📚', '용어 ${widget.glossaryCount}개'),
      if (widget.streakCount > 0) ('🔥', '연속 ${widget.streakCount}일째 학습'),
    ];

    return KeyedSubtree(
      key: const ValueKey('result'),
      child: AchievementSummary(
        displayTitle: '$_correctCount / $total',
        displayColor: allCorrect ? c.accent : textPrimary,
        subtitle: copyLine,
        subtitleColor: textPrimary,
        statsLabel: '오늘 배운 것',
        statRows: stats,
        onClose: () => Navigator.pop(context),
        secondaryAction: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: const Text(
              '공유하기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: c.accent,
            ),
          ),
        ),
      ),
    );
  }
}
