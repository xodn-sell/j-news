import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  await MobileAds.instance.initialize();

  try {
    await NotificationService.init(
      onNotificationTap: (payload) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialRegion: payload),
            ),
            (route) => false,
          );
        }
      },
    );
    await NotificationService.scheduleDailyNews();
  } catch (e) {
    debugPrint('[J-news] 알림 초기화 실패: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.notoSansTextTheme();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'J-news',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          brightness: Brightness.light,
          surface: const Color(0xFFFBFBFE),
          primary: const Color(0xFF1B2838),
          onPrimary: Colors.white,
          secondary: const Color(0xFF0066FF),
          surfaceContainerHighest: const Color(0xFFF1F3F9),
        ),
        useMaterial3: true,
        textTheme: baseTextTheme.copyWith(
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.8, color: const Color(0xFF121212)),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.2, color: const Color(0xFF121212)),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: const Color(0xFF121212)),
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
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
