import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../models/news_result.dart';
import '../services/quiz_service.dart';
import '../services/review_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// ── 디자인 토큰 (DESIGN.md 준수) ─────────────────────────────
// accent: #0052CC  (DESIGN.md colors.light.accent)
// success: #34C759 (DESIGN.md colors.light.success)
// error: #FF3B30   (DESIGN.md colors.light.error)
// textPrimary: #0D1117 (DESIGN.md colors.light.textPrimary)
// surfaceAlt: #F5F6FA  (DESIGN.md colors.light.surfaceAlt)
// radius xl=24, md=16, lg=18 (DESIGN.md radius)
// motion: 200ms easeInOut (DESIGN.md motion.fade — editorial tone)

const _kAccent = Color(0xFF0052CC);
const _kSuccess = Color(0xFF34C759);
const _kErrorRed = Color(0xFFFF3B30);
const _kTextPrimary = Color(0xFF0D1117);
const _kSurfaceAlt = Color(0xFFF5F6FA);
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

    return Scaffold(
      backgroundColor:
          isDark ? theme.colorScheme.surface : _kSurfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: _phase == _QuizPhase.question
            ? _buildProgressDots(isDark)
            : null,
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: _kFeedbackDuration,
          child: _buildPhase(theme, isDark),
        ),
      ),
    );
  }

  Widget _buildPhase(ThemeData theme, bool isDark) {
    switch (_phase) {
      case _QuizPhase.intro:
        return _buildIntro(theme, isDark);
      case _QuizPhase.question:
        return _buildQuestion(theme, isDark);
      case _QuizPhase.result:
        return _buildResult(theme, isDark);
    }
  }

  // ── 진행 도트 ────────────────────────────────────────────
  Widget _buildProgressDots(bool isDark) {
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
            color: done
                ? _kAccent
                : current
                    ? _kAccent
                    : _kAccent.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── A. 인트로 ────────────────────────────────────────────
  Widget _buildIntro(ThemeData theme, bool isDark) {
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : _kTextPrimary;
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
              color: _kAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.quiz_rounded,
                color: _kAccent, size: 28),
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
                backgroundColor: _kAccent,
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
  Widget _buildQuestion(ThemeData theme, bool isDark) {
    final q = _currentQ;
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : _kTextPrimary;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;

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
                  color: _kAccent.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  q.type == 'ox' ? 'O/X' : '4지선다',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _kAccent,
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
                      color: _kAccent.withValues(alpha: 0.08)),
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

          // 선택지
          ...List.generate(q.options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChoice(
                  i, q.options[i], q.answerIndex, isDark, textPrimary),
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
                  backgroundColor: _kAccent,
                  disabledBackgroundColor:
                      _kAccent.withValues(alpha: 0.30),
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
          if (_revealed) _buildFeedbackPanel(q, isDark, textPrimary),
        ],
      ),
    );
  }

  Widget _buildChoice(int idx, String label, int answerIdx,
      bool isDark, Color textPrimary) {
    // 상태 계산
    final isSelected = _selectedOption == idx;
    final isAnswer = idx == answerIdx;

    Color borderColor;
    Color bgColor;
    Widget? trailingIcon;

    if (_revealed) {
      if (isAnswer) {
        // 정답
        borderColor = _kSuccess;
        bgColor = _kSuccess.withValues(alpha: 0.08);
        trailingIcon = const Icon(Icons.check_circle_rounded,
            color: _kSuccess, size: 20);
      } else if (isSelected) {
        // 내가 고른 오답
        borderColor = _kErrorRed;
        bgColor = _kErrorRed.withValues(alpha: 0.08);
        trailingIcon = const Icon(Icons.cancel_rounded,
            color: _kErrorRed, size: 20);
      } else {
        borderColor = Colors.transparent;
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : _kSurfaceAlt;
      }
    } else if (isSelected) {
      // 선택됨(미확정)
      borderColor = _kAccent;
      bgColor = _kAccent.withValues(alpha: 0.06);
    } else {
      borderColor = Colors.transparent;
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : _kSurfaceAlt;
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

  Widget _buildFeedbackPanel(
      QuizQuestion q, bool isDark, Color textPrimary) {
    final isCorrect = _selectedOption == q.answerIndex;
    final stateColor = isCorrect ? _kSuccess : _kErrorRed;
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
                    backgroundColor: _kAccent,
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

  // ── C. 결과 화면 ─────────────────────────────────────────
  Widget _buildResult(ThemeData theme, bool isDark) {
    final total = widget.questions.length;
    final allCorrect = _correctCount == total;
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : _kTextPrimary;
    final cardBg =
        isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
    final scoreColor =
        allCorrect ? _kAccent : textPrimary;
    final copyLine = allCorrect
        ? '모두 맞혔어요!'
        : '$_correctCount개 맞혔어요';

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 점수 디스플레이 (DESIGN.md display 34px w900)
          Text(
            '$_correctCount / $total',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copyLine,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 28),

          // "오늘 배운 것" 카드 (radius xl=24)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(_kCardRadius),
              border: isDark
                  ? null
                  : Border.all(
                      color: _kAccent.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 배운 것',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary.withValues(alpha: 0.45),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 16),
                _statRow(
                    '📰', '뉴스 ${widget.newsCount}개 읽음', textPrimary),
                const SizedBox(height: 12),
                _statRow(
                    '🧠', '퀴즈 $_correctCount개 맞힘', textPrimary),
                if (widget.glossaryCount > 0) ...[
                  const SizedBox(height: 12),
                  _statRow('📚',
                      '용어 ${widget.glossaryCount}개', textPrimary),
                ],
                if (widget.streakCount > 0) ...[
                  const SizedBox(height: 12),
                  _statRow('🔥',
                      '연속 ${widget.streakCount}일째 학습', textPrimary),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 마무리 텍스트
          Center(
            child: Text(
              '내일 또 만나요',
              style: TextStyle(
                fontSize: 14,
                color: textPrimary.withValues(alpha: 0.40),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 닫기 (메인 CTA)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(_kBtnRadius)),
              ),
              child: const Text(
                '닫기',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 공유하기 (보조)
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text(
                '공유하기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _kAccent,
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
