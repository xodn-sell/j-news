import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart' show themeModeNotifier;
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'about_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const SettingsScreen({super.key, this.onChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '로그아웃 하시겠어요?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        content: const Text(
          '로그아웃해도 계정의 출석 기록은 보존됩니다.\n다음에 같은 Google 계정으로 다시 로그인하세요.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    FirebaseAnalytics.instance.logEvent(name: 'logout_pressed');
    try {
      await AuthService.signOut();
    } catch (_) {}
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _changeTheme(BuildContext context) async {
    final current = themeModeNotifier.value;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '테마 선택',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        children: [
          _ThemeOption(label: '라이트', icon: Icons.light_mode_rounded, value: ThemeMode.light, current: current),
          _ThemeOption(label: '다크', icon: Icons.dark_mode_rounded, value: ThemeMode.dark, current: current),
          _ThemeOption(label: '시스템', icon: Icons.brightness_auto_rounded, value: ThemeMode.system, current: current),
        ],
      ),
    );
    if (selected == null) return;
    themeModeNotifier.value = selected;
    String key = 'system';
    if (selected == ThemeMode.light) key = 'light';
    if (selected == ThemeMode.dark) key = 'dark';
    await SettingsService.saveThemeMode(key);
    FirebaseAnalytics.instance.logEvent(name: 'theme_changed', parameters: {'theme': key});
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '라이트';
      case ThemeMode.dark:
        return '다크';
      case ThemeMode.system:
        return '시스템';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? theme.colorScheme.surface : const Color(0xFFF5F6FA);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.07);
    final subColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    final versionLabel = _version.isEmpty ? '' : 'v$_version';

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0D1117),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 앱 브랜딩 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A1628), Color(0xFF0D2060), Color(0xFF1B3FA6)],
                          stops: [0.0, 0.45, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('J', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'J-NEWS',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'AI 뉴스 브리핑 · 매일 아침·저녁',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (versionLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                              ),
                              child: Text(
                                versionLabel,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 섹션: 화면 설정
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        '화면',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: subColor),
                      ),
                    ),

                    // 테마 타일
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeModeNotifier,
                      builder: (context, currentMode, _) => _SettingsTile(
                        cardBg: cardBg,
                        borderColor: borderColor,
                        iconBg: theme.colorScheme.secondary.withValues(alpha: 0.10),
                        icon: currentMode == ThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : currentMode == ThemeMode.light
                                ? Icons.light_mode_rounded
                                : Icons.brightness_auto_rounded,
                        iconColor: theme.colorScheme.secondary,
                        title: '테마',
                        subtitle: _themeModeLabel(currentMode),
                        isDark: isDark,
                        onTap: () => _changeTheme(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 섹션: 앱
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 18),
                      child: Text(
                        '앱',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: subColor),
                      ),
                    ),
                    _SettingsTile(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      iconBg: theme.colorScheme.primary.withValues(alpha: 0.09),
                      icon: Icons.info_outline_rounded,
                      iconColor: theme.colorScheme.primary,
                      title: '앱 정보',
                      subtitle: '공지 · 서비스 소개',
                      isDark: isDark,
                      onTap: () {
                        FirebaseAnalytics.instance.logEvent(name: 'about_screen_opened');
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                      },
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      iconBg: const Color(0xFFE53935).withValues(alpha: 0.10),
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFE53935),
                      title: '로그아웃',
                      subtitle: '다른 계정으로 전환하거나 로그아웃',
                      isDark: isDark,
                      onTap: () => _confirmAndLogout(context),
                    ),
                    const SizedBox(height: 48),

                    // 하단 서명
                    Center(
                      child: Column(
                        children: [
                          Text(
                            versionLabel.isEmpty ? 'J-NEWS' : 'J-NEWS $versionLabel',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '매일 읽는 뉴스, 쌓이는 지식',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode current;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = value == current;
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: selected ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? theme.colorScheme.secondary : theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check_rounded, size: 18, color: theme.colorScheme.secondary),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Color cardBg;
  final Color borderColor;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.cardBg,
    required this.borderColor,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0D1117)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
