import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../theme/jnews_colors.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  bool _agreeRequired = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'login_shown');
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _showConsentDialog({required bool privacy}) {
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            privacy ? '개인정보처리방침' : '서비스 이용약관',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: size.width,
            height: size.height * 0.55,
            child: SingleChildScrollView(
              child: Text(
                privacy ? _privacyPolicyText : _termsOfServiceText,
                style: const TextStyle(fontSize: 12.5, height: 1.65),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
          ],
        );
      },
    );
  }

  static const String _termsOfServiceText = '''제1조 (목적)
본 약관은 지음뉴스(이하 "회사")가 제공하는 J-news 모바일 애플리케이션 및 관련 서비스(이하 "서비스")의 이용 조건과 절차, 회사와 이용자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (정의)
1. "서비스"란 AI 기반 뉴스 요약·브리핑, AI 토론, 오디오 브리핑 등을 포함한 모든 기능을 의미합니다.
2. "이용자"란 본 약관에 동의하고 서비스를 이용하는 회원을 말합니다.

제3조 (서비스의 제공)
1. 회사는 AI 기반 뉴스 큐레이션, AI 토론, 오디오 브리핑 등의 서비스를 제공합니다.
2. 서비스는 24시간 제공을 원칙으로 하나, 점검·장애·천재지변 등의 사유로 일시 중단될 수 있습니다.

제4조 (회원 가입 및 탈퇴)
1. 이용자는 Google 계정 등을 통해 가입할 수 있으며, 본 약관에 동의함으로써 회원 자격을 취득합니다.
2. 이용자는 언제든지 탈퇴할 수 있으며, 탈퇴 시 계정 정보 및 이용 기록은 모두 삭제됩니다.

제5조 (이용자의 의무)
1. 이용자는 관계 법령, 본 약관, 회사가 공지하는 사항을 준수해야 합니다.
2. 이용자는 다음 행위를 해서는 안 됩니다.
   - 허위 정보 등록 또는 타인의 계정 도용
   - 자동화 프로그램·매크로 등을 이용한 어뷰징
   - 서비스의 정상 운영을 방해하는 행위

제6조 (서비스의 변경 및 중단)
회사는 운영상·기술상 필요에 따라 서비스 내용을 변경할 수 있으며, 이 경우 사전 공지합니다.

제7조 (책임의 제한)
1. 회사는 천재지변, 통신 장애 등 불가항력 사유로 서비스를 제공할 수 없는 경우 책임을 지지 않습니다.
2. 회사는 이용자가 서비스를 통해 얻은 정보로 입은 손해에 대해 직접적·구체적 책임을 지지 않습니다.

제8조 (분쟁 해결)
서비스 이용과 관련하여 발생한 분쟁은 회사와 이용자가 상호 협의하여 해결하며, 협의가 이루어지지 않을 경우 관련 법령에 따릅니다.

부칙
본 약관은 2026년 6월 5일부터 시행합니다.
문의: xowns142857@gmail.com''';

  static const String _privacyPolicyText = '''지음뉴스(이하 "회사")는 정보통신망 이용촉진 및 정보보호 등에 관한 법률, 개인정보 보호법 등 관련 법령에 따라 이용자의 개인정보를 보호하고 권익을 존중합니다.

제1조 (수집하는 개인정보 항목)
1. 회원 가입 및 인증
   - 필수: 이메일, 사용자 식별자(uid), 프로필 정보(닉네임, 프로필 사진)
2. 서비스 이용 과정에서 자동 수집
   - 단말기 정보(OS, 기기 모델, 광고 식별자)
   - 서비스 이용 기록(접속 일시, 뉴스 조회·완독 기록)

제2조 (수집 방법)
- Google·소셜 로그인을 통한 자동 수집
- 서비스 이용 시 자동 생성·수집

제3조 (이용 목적)
1. 회원 식별 및 인증
2. AI 뉴스 요약·브리핑 제공
3. 부정 이용 방지
4. 서비스 개선 및 통계 분석
5. 이벤트·공지사항 안내(필요시)

제4조 (보유 및 이용 기간)
- 회원 정보: 회원 탈퇴 시까지(법령상 보존 의무가 있는 경우 해당 기간까지)
- 1년 이상 미접속 시 휴면 계정으로 분리되어 별도 관리
- 부정 이용 기록: 위법 행위 방지 목적으로 1년간 보관

제5조 (개인정보 제3자 제공)
회사는 이용자의 개인정보를 원칙적으로 제3자에게 제공하지 않습니다. 다만, 다음의 경우는 예외로 합니다.
- 이용자가 사전에 동의한 경우
- 법령의 규정에 의거하거나 수사기관의 요구가 있는 경우

제6조 (개인정보 처리 위탁)
- Google Firebase(인증·분석·푸시 알림): Google LLC
- 클라우드 서버: Vercel Inc.
- 광고 게재: Google AdMob

제7조 (이용자의 권리)
이용자는 언제든지 개인정보 열람·정정·삭제·처리 정지를 요구할 수 있으며, 이메일(xowns142857@gmail.com)로 요청할 수 있습니다. 회원 탈퇴 시 모든 개인정보는 즉시 파기됩니다.

제8조 (개인정보의 안전성 확보 조치)
- 암호화 저장(이메일·인증 토큰)
- 접근 통제 및 권한 관리
- 보안 프로그램 설치 및 주기적 점검

제9조 (개인정보 보호 책임자)
- 책임자: 김태우
- 이메일: xowns142857@gmail.com
- 연락처: J-news 앱 내 [설정 > 문의하기]

제10조 (변경 사항 고지)
본 방침은 법령·정책 변경에 따라 수정될 수 있으며, 변경 시 최소 7일 전 앱 내 공지로 고지합니다.

시행일: 2026년 4월 25일''';

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    if (!_agreeRequired) {
      setState(() => _errorMessage = '필수 약관에 동의해주세요.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    final analytics = FirebaseAnalytics.instance;
    final attemptStart = DateTime.now();
    analytics.logEvent(name: 'login_attempt');

    try {
      final user = await AuthService.signInWithGoogle();
      if (user == null) {
        analytics.logEvent(name: 'login_cancelled');
        setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;

      final durationMs = DateTime.now().difference(attemptStart).inMilliseconds;
      await analytics.setUserId(id: user.uid);
      await analytics.setUserProperty(name: 'signed_in', value: 'true');
      analytics.logEvent(name: 'login_success', parameters: {
        'duration_ms': durationMs,
      });

      final prefs = await SharedPreferences.getInstance();
      // uid-scoped onboarding flag (신규 계정이면 false)
      bool onboardingDone = prefs.getBool('onboarding_done_${user.uid}') ?? false;

      // 레거시 마이그레이션: 같은 디바이스에서 이전 앱 버전을 쓰던 유저의
      // 기존 `onboarding_done` 플래그가 있고, 이게 바로 이 계정일 수 있음.
      // 안전하게 처리하려면: 레거시 true이고 이 uid에 기록이 없을 때만
      // 승격. 다계정 공유 디바이스에서 신규 계정이 무단 skip하는 것을
      // 방지하려면 서버측 first_mission_claimed로 재확인.
      if (!onboardingDone) {
        final legacy = prefs.getBool('onboarding_done') ?? false;
        if (legacy) {
          // 보수적으로 false 유지 (신규 가입자는 온보딩+100pt 받아야 함)
          // 레거시 키는 main.dart에서 이미 처리됐을 것.
          onboardingDone = false;
        }
      }

      analytics.logEvent(name: 'login_routed', parameters: {
        'destination': onboardingDone ? 'home' : 'onboarding',
      });

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => onboardingDone
              ? const HomeScreen()
              : const OnboardingScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      analytics.logEvent(
        name: 'login_fail',
        parameters: {'error': e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)},
      );
      setState(() { _isLoading = false; _errorMessage = '로그인에 실패했습니다. 다시 시도해주세요.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.jColors;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.surfaceElevated, c.surfaceTint, c.surfaceTintDeep],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // 배경 장식 원
            Positioned(
              top: -100, right: -80,
              child: _DecorCircle(size: 280, color: c.accent, opacity: 0.06),
            ),
            Positioned(
              top: 60, right: 10,
              child: _DecorCircle(size: 110, color: c.accent, opacity: 0.05),
            ),
            Positioned(
              bottom: -130, left: -100,
              child: _DecorCircle(size: 340, color: c.accent, opacity: 0.07),
            ),
            Positioned(
              bottom: 180, right: -40,
              child: _DecorCircle(size: 150, color: c.accentLight, opacity: 0.08),
            ),
            Positioned(
              top: 280, left: -30,
              child: _DecorCircle(size: 100, color: c.accentLight, opacity: 0.06),
            ),

            // 메인 콘텐츠
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),

                        // 로고
                        Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.30),
                                blurRadius: 32,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset('assets/app_icon.png', width: 84, height: 84, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'J-NEWS',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: c.textPrimary,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI가 매일 골라주는 오늘의 핵심 뉴스',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: c.textPrimary.withValues(alpha: 0.45),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),

                        // 피처 하이라이트
                        const _FeatureRow(icon: '📰', title: '하루 3번 AI 뉴스 브리핑', sub: '아침·점심·저녁 자동 큐레이션'),
                        const SizedBox(height: 8),
                        const _FeatureRow(icon: '💬', title: 'AI랑 뉴스 토론', sub: '궁금한 점 바로 물어보기'),
                        const SizedBox(height: 8),
                        const _FeatureRow(icon: '🎧', title: '오디오로 듣기', sub: '진행자 2명의 라디오 브리핑'),

                        const SizedBox(height: 20),

                        // 에러
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.error.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: c.errorAlt, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 약관 동의 체크박스
                        _ConsentRow(
                          required: true,
                          label: '이용약관 · 개인정보처리방침 동의',
                          checked: _agreeRequired,
                          onChanged: (v) => setState(() {
                            _agreeRequired = v;
                            if (v) _errorMessage = null;
                          }),
                          onViewTap: () => _showConsentDialog(privacy: false),
                          onViewTap2: () => _showConsentDialog(privacy: true),
                        ),
                        const SizedBox(height: 10),

                        // Google 로그인 버튼 (베네핏 강조 CTA)
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_agreeRequired) ? null : _handleGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.surfaceElevated,
                              foregroundColor: c.textPrimary,
                              disabledBackgroundColor: c.surfaceElevated.withValues(alpha: 0.55),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const _GoogleLogo(size: 20),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Google로 시작하기',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                              color: _agreeRequired
                                                  ? c.textPrimary
                                                  : c.textPrimary.withValues(alpha: 0.45),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _agreeRequired ? 'Google 계정으로 3초만에' : '약관 동의 후 진행 가능',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.textPrimary.withValues(alpha: 0.48),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final String title;
  final String sub;

  const _FeatureRow({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final c = context.jColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surfaceElevated.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent.withValues(alpha: 0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(fontSize: 12, color: c.textPrimary.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool required;
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewTap;
  final VoidCallback? onViewTap2;

  const _ConsentRow({
    required this.required,
    required this.label,
    required this.checked,
    required this.onChanged,
    this.onViewTap,
    this.onViewTap2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.jColors;
    final tagColor = required ? c.accent : c.textMuted;
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: checked ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? c.accent : c.textPrimary.withValues(alpha: 0.30),
                  width: 1.6,
                ),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 14, color: c.textInverse)
                  : null,
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                required ? '필수' : '선택',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tagColor, letterSpacing: -0.2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textPrimary.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (onViewTap != null) ...[
              GestureDetector(
                onTap: onViewTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '약관',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.accent.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              if (onViewTap2 != null)
                GestureDetector(
                  onTap: onViewTap2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '정책',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.accent.withValues(alpha: 0.80),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
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

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _DecorCircle({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 1.5),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _GoogleLogoPainter()));
  }
}


class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final sw = size.width * 0.18;

    Paint p(Color c) => Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75);
    canvas.drawArc(rect, 0.55, 1.15, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, 1.7, 1.1, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, 2.8, 1.1, false, p(const Color(0xFF4285F4)));
    canvas.drawArc(rect, 3.9, 0.95, false, p(const Color(0xFFFBBC05)));
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.7, cy),
        Paint()..color = const Color(0xFF4285F4)..strokeWidth = sw..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}
