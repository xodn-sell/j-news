import 'package:flutter/material.dart';
import '../services/concept_service.dart';

/// 완독 화면 상단 진척 카드 — 누적 학습 자산 시각화.
/// 완독보너스(포인트)를 대체하는 retention hook: "오늘 만난 개념 / 누적 습득".
class ConceptProgressCard extends StatelessWidget {
  final ConceptProgress progress;

  /// 이번 세션에 새로 만난 개념 수 (옵션, >0이면 강조 배지).
  final int newThisSession;

  const ConceptProgressCard({
    super.key,
    required this.progress,
    this.newThisSession = 0,
  });

  static const _domainLabels = {
    'politics': '정치',
    'economy': '경제',
    'society': '사회',
    'tech': '기술',
    'foreign': '외교',
    'etc': '기타',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    // mastery 진행 중인 상위 도메인 (total 큰 순 3개)
    final domains = [...progress.domains]
      ..sort((a, b) => b.total.compareTo(a.total));
    final topDomains = domains.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onSurface.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 18, color: primary),
              const SizedBox(width: 6),
              Text('나의 배경지식',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: onSurface.withValues(alpha: 0.55))),
              const Spacer(),
              if (newThisSession > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('오늘 +$newThisSession',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: primary)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat(context, '$_encountered', '만난 개념', primary),
              _divider(onSurface),
              _stat(context, '${progress.mastered}', '습득', onSurface),
              _divider(onSurface),
              _stat(context, '${progress.learning}', '학습 중', onSurface),
            ],
          ),
          if (topDomains.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...topDomains.map((d) => _domainBar(context, d, primary, onSurface)),
          ],
          if (progress.dueToday > 0) ...[
            const SizedBox(height: 10),
            Text('오늘 복습할 개념 ${progress.dueToday}개',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary.withValues(alpha: 0.85))),
          ],
        ],
      ),
    );
  }

  int get _encountered => progress.encountered;

  Widget _stat(BuildContext context, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _divider(Color onSurface) => Container(
      width: 1, height: 30, color: onSurface.withValues(alpha: 0.08));

  Widget _domainBar(
      BuildContext context, DomainProgress d, Color primary, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(_domainLabels[d.domain] ?? d.domain,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: onSurface.withValues(alpha: 0.5))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: d.ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: onSurface.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${d.mastered}/${d.total}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
