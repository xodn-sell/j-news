import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? const Color(0xFF0D1333) : const Color(0xFF1A237E),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: isDark ? Colors.grey[300] : Colors.white),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome, size: 48, color: Colors.amber),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'J-news Pro',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.grey[100] : Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI가 분석한 세상을 가장 빠르게 만나보세요',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                            ? Colors.grey[400]
                            : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 48),
                      _buildFeatureItem(
                        Icons.category_outlined,
                        '모든 카테고리 잠금 해제',
                        '테크, 경제, 연예 등 전문 분야 뉴스 제공',
                        isDark,
                      ),
                      _buildFeatureItem(
                        Icons.notifications_active_outlined,
                        '개인 맞춤 키워드 알림',
                        '내 관심사 뉴스가 뜨면 즉시 알림 발송',
                        isDark,
                      ),
                      _buildFeatureItem(
                        Icons.psychology_outlined,
                        'AI 심층 분석 리포트',
                        '뉴스 이면의 시사점과 영향력 심층 분석',
                        isDark,
                      ),
                      _buildFeatureItem(
                        Icons.block_outlined,
                        '광고 없는 클린 모드',
                        '방해 없이 뉴스에만 집중하세요',
                        isDark,
                      ),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '월 2,900원',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const Text(
                                  ' (7일 무료 체험)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton(
                                onPressed: () async {
                                  // Pro 상태 저장 (실제 IAP 연동 시 여기에 구현)
                                  await CacheService.setProStatus(true);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pro 구독이 시작되었습니다! (데모)')),
                                    );
                                    Navigator.pop(context, true); // true 반환으로 Pro 활성화 알림
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text(
                                  '무료 체험 시작하기',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '언제든지 취소 가능합니다.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? Colors.grey[300] : Colors.white, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[200] : Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                      ? Colors.grey[500]
                      : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
