import 'package:flutter/material.dart';
import '../theme/jnews_colors.dart';

// ── 디자인 토큰 (DESIGN.md 준수 — Editorial 톤) ──────────────
// radius: xl=24 (카드), lg=18 (버튼)
// motion: 200ms easeInOut fade만
const _kCardRadius = 24.0; // radius.xl
const _kBtnRadius = 18.0; // radius.lg

/// 완료/결과 화면 공용 위젯 — review_screen & quiz_screen 양쪽에서 사용.
///
/// DESIGN.md 레이아웃:
/// - display 타이포 (34px w900, letterSpacing -1.2)
/// - 부제 (20px w800)
/// - 통계 카드 (radius.xl=24, border accent 8%)
/// - "내일 또 만나요" 푸터
/// - 닫기 FilledButton (accent, 52h)
/// - 선택적 보조 액션 (TextButton — 공유 등)
class AchievementSummary extends StatelessWidget {
  /// 상단 display 타이포 (예: "복습 완료", "2 / 3")
  final String displayTitle;

  /// display 타이포 색. null이면 textPrimary.
  final Color? displayColor;

  /// 부제 (예: "오늘 복습 5개 완료", "2개 맞혔어요")
  final String subtitle;

  /// 부제 색. null이면 accent.
  final Color? subtitleColor;

  /// 통계 카드 헤더 레이블 (예: "누적 학습", "오늘 배운 것")
  final String statsLabel;

  /// 통계 행 목록. 각 항목: (emoji, label)
  final List<(String, String)> statRows;

  /// 닫기 버튼 탭 콜백
  final VoidCallback onClose;

  /// 선택적 보조 액션 버튼 (예: 공유). null이면 미노출.
  final Widget? secondaryAction;

  const AchievementSummary({
    super.key,
    required this.displayTitle,
    this.displayColor,
    required this.subtitle,
    this.subtitleColor,
    required this.statsLabel,
    required this.statRows,
    required this.onClose,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = context.jColors;
    final textPrimary =
        isDark ? theme.colorScheme.onSurface : c.textPrimary;
    final cardBg =
        isDark ? theme.colorScheme.surfaceContainerHighest : c.surfaceElevated;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── display 타이포 (DESIGN.md display 34px w900) ──
          Text(
            displayTitle,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              color: displayColor ?? textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: subtitleColor ?? c.accent,
            ),
          ),
          const SizedBox(height: 28),

          // ── 통계 카드 ──────────────────────────────────────
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
                  statsLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: textPrimary.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 16),
                ...statRows.indexed.map(((int, (String, String)) pair) {
                  final i = pair.$1;
                  final row = pair.$2;
                  return Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                    child: _StatRow(emoji: row.$1, label: row.$2, textPrimary: textPrimary),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── "내일 또 만나요" ────────────────────────────────
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

          // ── 닫기 (메인 CTA 1개 원칙) ───────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBtnRadius)),
              ),
              child: const Text(
                '닫기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),

          // ── 보조 액션 (선택) ────────────────────────────────
          if (secondaryAction != null) ...[
            const SizedBox(height: 12),
            secondaryAction!,
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String emoji;
  final String label;
  final Color textPrimary;

  const _StatRow({
    required this.emoji,
    required this.label,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
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
