import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'services/native_ad_service.dart';
import 'services/auth_service.dart';
import 'theme/jnews_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  final bootStart = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();

  // 부팅 시 초기 오버레이 스타일 — 이후 AppBarTheme.systemOverlayStyle 이 덮어씀
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await Firebase.initializeApp();
  final analytics = FirebaseAnalytics.instance;
  analytics.logAppOpen();

  await AuthService.init();

  // 로그인된 유저면 GA userId / user_property 세팅
  final uid = AuthService.uid;
  if (uid != null) {
    await analytics.setUserId(id: uid);
    await analytics.setUserProperty(name: 'signed_in', value: 'true');
  } else {
    await analytics.setUserProperty(name: 'signed_in', value: 'false');
  }

  await MobileAds.instance.initialize();
  NativeAdService.preload();

  try {
    await NotificationService.init(
      onNotificationTap: (payload) {
        analytics.logEvent(name: 'notification_tapped', parameters: {
          'payload': (payload ?? '').length > 80
              ? payload!.substring(0, 80)
              : (payload ?? ''),
        });
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      },
    );
    await NotificationService.scheduleDailyNews();
  } catch (e) {
    debugPrint('[J-news] 알림 초기화 실패: $e');
    analytics.logEvent(name: 'notification_init_fail', parameters: {
      'error': e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString(),
    });
  }

  final prefs = await SharedPreferences.getInstance();
  // 기본 라이트 — 다크는 설정에서 명시 선택한 유저만 (시스템 추종 기본은 첫인상 저하)
  final themeModeStr = prefs.getString('theme_mode') ?? 'light';
  final isSignedIn = AuthService.isSignedIn;

  // uid-scoped onboarding flag + legacy migration
  bool onboardingDone = false;
  if (isSignedIn && uid != null) {
    onboardingDone = prefs.getBool('onboarding_done_$uid') ?? false;

    // 레거시 마이그레이션: 이전 앱 버전에서 디바이스 단위 저장된 플래그를
    // 현재 uid로 한 번만 승격. 이후 uninstall/reinstall 시에도 유지.
    final legacy = prefs.getBool('onboarding_done') ?? false;
    if (legacy && !prefs.containsKey('onboarding_done_$uid')) {
      await prefs.setBool('onboarding_done_$uid', true);
      onboardingDone = true;
    }
  }

  themeModeNotifier.value = _parseThemeMode(themeModeStr);

  final bootDurationMs = DateTime.now().difference(bootStart).inMilliseconds;
  analytics.logEvent(name: 'app_boot', parameters: {
    'duration_ms': bootDurationMs,
    'signed_in': isSignedIn ? 1 : 0,
    'onboarding_done': onboardingDone ? 1 : 0,
  });

  runApp(MyApp(
    showOnboarding: !onboardingDone,
    isSignedIn: isSignedIn,
  ));
}

// 앱 전체에서 테마 변경을 위한 notifier
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

ThemeMode _parseThemeMode(String s) {
  if (s == 'light') return ThemeMode.light;
  if (s == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  final bool isSignedIn;
  const MyApp({
    super.key,
    this.showOnboarding = false,
    this.isSignedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.notoSansTextTheme();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
      navigatorKey: navigatorKey,
      title: 'J-news',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        extensions: const [JNewsColors.light],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          brightness: Brightness.light,
          surface: const Color(0xFFFBFBFE),
          primary: const Color(0xFF1B2838),
          onPrimary: Colors.white,
          secondary: const Color(0xFF0052CC),
          surfaceContainerHighest: const Color(0xFFF1F3F9),
        ),
        useMaterial3: true,
        textTheme: baseTextTheme.copyWith(
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.8, color: const Color(0xFF0D1117)),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.2, color: const Color(0xFF0D1117)),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: const Color(0xFF0D1117)),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.75, letterSpacing: -0.3, color: const Color(0xFF2D2D2D)),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.65, letterSpacing: -0.2, color: const Color(0xFF424242)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFF003366).withValues(alpha: 0.06), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFFFBFBFE),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1B2838),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      darkTheme: ThemeData(
        extensions: const [JNewsColors.dark],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B2838),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F1115),
          primary: const Color(0xFF8AB4F8),
          onPrimary: const Color(0xFF0F1115),
          secondary: const Color(0xFF4A90D9),
          surfaceContainerHighest: const Color(0xFF1C1F26),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme).copyWith(
          headlineLarge: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.white),
          headlineMedium: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Colors.white),
          bodyLarge: const TextStyle(height: 1.7, letterSpacing: -0.2),
          bodyMedium: const TextStyle(height: 1.6, letterSpacing: -0.1),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1C1F26),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF0F1115),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      themeMode: themeMode,
      home: !isSignedIn
          ? const LoginScreen()
          : showOnboarding
              ? const OnboardingScreen()
              : const HomeScreen(),
    ));
  }
}
