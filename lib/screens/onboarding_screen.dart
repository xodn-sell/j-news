import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isFinishing = false;
  bool _notificationOptIn = true;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _entryController.forward();
    });

    FirebaseAnalytics.instance.logEvent(name: 'onboarding_shown');
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;

    final analytics = FirebaseAnalytics.instance;
    analytics.logEvent(name: 'onboarding_start_pressed', parameters: {
      'notification_opt_in': _notificationOptIn ? 1 : 0,
    });
    setState(() => _isFinishing = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_opt_in', _notificationOptIn);
    bool notificationGranted = false;
    if (_notificationOptIn) {
      try {
        notificationGranted = await NotificationService.requestPermissions();
        analytics.logEvent(
          name: 'notification_permission_requested',
          parameters: {'from': 'onboarding', 'granted': notificationGranted ? 1 : 0},
        );
      } catch (_) {}
    }

    final uid = AuthService.uid;

    if (uid != null) {
      await prefs.setBool('onboarding_done_$uid', true);
    }

    if (!mounted) return;
    setState(() => _isFinishing = false);

    analytics.logEvent(name: 'onboarding_complete', parameters: {
      'notification_opt_in': _notificationOptIn ? 1 : 0,
      'notification_granted': notificationGranted ? 1 : 0,
    });

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Stack(
        children: [
          // 배경 블롭 (safe area 무시, 시스템 바까지 뻗음)
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0052CC).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -100,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFC107).withValues(alpha: 0.10),
              ),
            ),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isFinishing ? null : _finish,
            child: Padding(
              padding: EdgeInsets.only(
                top: viewPadding.top + 12,
                bottom: viewPadding.bottom + 12,
                left: 24,
                right: 24,
              ),
              child: SizedBox.expand(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // 로고
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0052CC)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/app_icon.png',
                                  width: 44,
                                  height: 44,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'J-NEWS',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: Color(0xFF0D1117),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0052CC)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '🌱  하루 1분 세계 뉴스',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0052CC),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 헤드라인
                        const Text(
                          '하루 1분,\n세상을 읽다',
                          style: TextStyle(
                            fontSize: 32,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: Color(0xFF0D1117),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'AI가 고른 오늘의 글로벌 뉴스,\n스와이프하며 빠르게 파악',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: const Color(0xFF0D1117)
                                .withValues(alpha: 0.55),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 3단계 카드
                        _buildStep(
                          1,
                          '📰',
                          '뉴스 카드 스와이프',
                          '좌우로 넘기며 오늘의 뉴스 확인',
                        ),
                        const SizedBox(height: 10),
                        _buildStep(
                          2,
                          '✨',
                          'AI 심층 인사이트',
                          '핵심 분석과 배경까지 한눈에',
                        ),
                        const SizedBox(height: 10),
                        _buildStep(
                          3,
                          '🎧',
                          '오디오 브리핑',
                          '진행자 2명의 라디오 스타일 요약',
                        ),

                        // 최소 간격 + 남는 공간
                        const SizedBox(height: 14),
                        const Spacer(),

                        // 구분선 — 단계 설명과 알림 섹션 분리
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          color: const Color(0xFF0D1117).withValues(alpha: 0.06),
                        ),

                        // 알림 opt-in (하단 블록)
                        GestureDetector(
                          onTap: () => setState(
                            () => _notificationOptIn = !_notificationOptIn,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _notificationOptIn
                                  ? const Color(0xFF0052CC)
                                      .withValues(alpha: 0.06)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _notificationOptIn
                                    ? const Color(0xFF0052CC)
                                        .withValues(alpha: 0.25)
                                    : const Color(0xFF0D1117)
                                        .withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _notificationOptIn
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 22,
                                  color: _notificationOptIn
                                      ? const Color(0xFF0052CC)
                                      : const Color(0xFF0D1117)
                                          .withValues(alpha: 0.3),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '아침·저녁 뉴스 알림 받기',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0D1117)
                                                  .withValues(alpha: 0.88),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '07:00 / 18:00 · 새 브리핑 알림',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF0D1117)
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // CTA
                        Center(
                          child: _isFinishing
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF0052CC),
                                  ),
                                )
                              : AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (ctx, _) {
                                    final t = _pulseController.value;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0052CC),
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0052CC)
                                                .withValues(
                                                  alpha: 0.25 + 0.15 * t,
                                                ),
                                            blurRadius: 20 + 8 * t,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        '👆  화면을 탭해서 시작',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        const SizedBox(height: 10),

                        Center(
                          child: Text(
                            '시작하면 개인정보처리방침 및 이용약관에 동의합니다',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: const Color(0xFF0D1117)
                                  .withValues(alpha: 0.32),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int n, String emoji, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0D1117).withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1117).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0052CC), Color(0xFF2E7BFF)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0052CC).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1117),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF0D1117).withValues(alpha: 0.5),
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
