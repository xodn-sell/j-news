import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with WidgetsBindingObserver {

  static const String _appVersion = '1.3.0';
  static const String _contactEmail = 'xowns142857@gmail.com';
  static const String _developerName = 'k-jieum';
  static const String _privacyUrl = 'https://backend-ruby-chi-85.vercel.app/privacy';
  static const String _termsUrl = 'https://backend-ruby-chi-85.vercel.app/terms';

  bool? _notificationGranted;
  bool? _exactAlarmGranted;
  bool? _batteryOptIgnored;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 권한 설정 화면에서 돌아올 때 상태 갱신
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await NotificationService.getPermissionStatus();
    if (mounted) {
      setState(() {
        _notificationGranted = status['notification'];
        _exactAlarmGranted = status['exactAlarm'];
        _batteryOptIgnored = status['batteryOptimization'];
      });
    }
  }

  Future<void> _requestPermissions() async {
    await NotificationService.requestPermissions();
    await _checkPermissions();
    // 권한 허용 후 알림 재스케줄
    await NotificationService.scheduleDailyNews();
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('테스트 알림을 전송했어요!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': '[J-news] 문의'},
    );
    try {
      await launchUrl(uri);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일 앱을 열 수 없습니다')),
        );
      }
    }
  }

  Widget _buildPermissionRow(ThemeData theme, String label, bool? granted) {
    final color = granted == true ? Colors.green : Colors.red;
    final icon = granted == true ? Icons.check_circle_outline : Icons.cancel_outlined;
    final text = granted == true ? '허용됨' : (granted == false ? '거부됨' : '확인 중...');
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: $text',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allGranted = (_notificationGranted ?? false) &&
        (_exactAlarmGranted ?? false) &&
        (_batteryOptIgnored ?? false);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('App Info & Contact / 앱 정보 및 문의'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 앱 로고 & 이름
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'J-news',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI 뉴스 브리핑',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '버전 $_appVersion',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 알림 설정
          _buildSection(
            theme: theme,
            isDark: isDark,
            title: '알림 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermissionRow(theme, '알림 권한', _notificationGranted),
                const SizedBox(height: 8),
                _buildPermissionRow(theme, '정확한 알람 권한', _exactAlarmGranted),
                const SizedBox(height: 8),
                _buildPermissionRow(theme, '배터리 최적화 제외', _batteryOptIgnored),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sendTestNotification,
                        icon: const Icon(Icons.notifications_outlined, size: 16),
                        label: const Text('테스트 알림'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (!allGranted) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _requestPermissions,
                          icon: const Icon(Icons.lock_open_outlined, size: 16),
                          label: const Text('권한 허용'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 앱 소개
          _buildSection(
            theme: theme,
            isDark: isDark,
            title: '앱 소개',
            child: Text(
              'J-news는 AI(Google Gemini)가 미국과 한국의 주요 뉴스를 '
              '요약·분석하여 제공하는 뉴스 브리핑 앱입니다.\n\n'
              '모든 뉴스 콘텐츠는 AI가 다양한 언론사의 기사를 기반으로 '
              '요약한 것이며, 각 뉴스의 원본 출처를 함께 제공합니다.\n\n'
              '• 미국 뉴스: 화~토 오전 8시 업데이트 (KST)\n'
              '• 한국 뉴스: 월~금 오후 6시 업데이트 (KST)',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 문의하기
          _buildSection(
            theme: theme,
            isDark: isDark,
            title: 'Contact Us / 문의하기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '앱 이용 중 문의사항, 피드백, 뉴스 콘텐츠 관련 제보 등은 '
                  '아래 이메일로 연락해 주세요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                // 운영자
                _buildInfoRow(
                  theme: theme,
                  icon: Icons.person_outline,
                  label: '운영자 (Operator)',
                  value: _developerName,
                ),
                const SizedBox(height: 12),
                // 이메일
                InkWell(
                  onTap: () => _sendEmail(context),
                  borderRadius: BorderRadius.circular(8),
                  child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.email_outlined,
                    label: '이메일 (Customer Support)',
                    value: _contactEmail,
                    isLink: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 콘텐츠 출처 안내
          _buildSection(
            theme: theme,
            isDark: isDark,
            title: '콘텐츠 출처 안내',
            child: Text(
              'J-news는 뉴스 애그리게이터 앱으로, Google Gemini AI가 '
              '다양한 언론사의 공개된 뉴스 기사를 기반으로 요약본을 생성합니다.\n\n'
              '각 뉴스 항목에는 원본 기사의 출처(언론사/게시자)와 '
              '링크가 함께 제공되며, 사용자는 원본 기사를 직접 확인할 수 있습니다.\n\n'
              'J-news는 자체적으로 뉴스를 생산하지 않으며, '
              '모든 콘텐츠의 저작권은 원 게시자에게 있습니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 면책 조항
          _buildSection(
            theme: theme,
            isDark: isDark,
            title: '면책 조항',
            child: Text(
              '본 서비스에서 제공하는 모든 뉴스 요약 및 분석은 '
              'AI(인공지능)가 자동으로 생성한 콘텐츠입니다.\n\n'
              'AI 생성 콘텐츠는 실제 사실과 다를 수 있으며, '
              '정확성·완전성·적시성을 보장하지 않습니다. '
              '중요한 정보는 반드시 원본 기사를 통해 직접 확인하시기 바랍니다.\n\n'
              '본 서비스는 언론사가 아니며, 뉴스 편집권이 없습니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 법적 문서 링크
          _buildSection(
            theme: theme,
            isDark: isDark,
            title: '법적 고지',
            child: Column(
              children: [
                InkWell(
                  onTap: () => launchUrl(Uri.parse(_privacyUrl), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(8),
                  child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.shield_outlined,
                    label: '개인정보처리방침',
                    value: '보기',
                    isLink: true,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(_termsUrl), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(8),
                  child: _buildInfoRow(
                    theme: theme,
                    icon: Icons.description_outlined,
                    label: '이용약관',
                    value: '보기',
                    isLink: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isLink
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
