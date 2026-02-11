import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.init(
      onNotificationTap: (payload) {
        // 알림 탭 시 해당 리전 탭으로 이동
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'J-news',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B3467),
          brightness: Brightness.light,
          surface: const Color(0xFFF8F9FA),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(
          ThemeData.light().textTheme,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B3467),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade800, width: 1),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
