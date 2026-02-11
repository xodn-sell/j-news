import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// 알림 탭 시 콜백 (main에서 네비게이션에 활용)
typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static NotificationTapCallback? onTap;

  static Future<void> init({NotificationTapCallback? onNotificationTap}) async {
    onTap = onNotificationTap;

    tz_data.initializeTimeZones();
    // 디바이스 타임존 감지
    try {
      final timeZoneName = DateTime.now().timeZoneName;
      // 일반적인 한국/미국 타임존 매핑
      final tzMap = {
        'KST': 'Asia/Seoul',
        'JST': 'Asia/Tokyo',
        'EST': 'America/New_York',
        'EDT': 'America/New_York',
        'CST': 'America/Chicago',
        'CDT': 'America/Chicago',
        'MST': 'America/Denver',
        'MDT': 'America/Denver',
        'PST': 'America/Los_Angeles',
        'PDT': 'America/Los_Angeles',
      };
      final location = tzMap[timeZoneName] ?? 'Asia/Seoul';
      tz.setLocalLocation(tz.getLocation(location));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    // Android 설정
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // macOS 설정
    const macOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: android,
      iOS: iOS,
      macOS: macOS,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Android 알림 권한 요청
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    onTap?.call(response.payload);
  }

  static Future<void> scheduleDailyNews() async {
    // 기존 스케줄 초기화
    await _plugin.cancelAll();

    // 매일 오전 8시 - 미국 뉴스
    await _scheduleDaily(
      id: 0,
      hour: 8,
      title: '🇺🇸 J-news 미국 브리핑',
      body: '오늘의 미국 주요 뉴스가 준비되었습니다. 확인해보세요!',
      payload: 'us',
    );

    // 매일 오후 6시 - 한국 뉴스
    await _scheduleDaily(
      id: 1,
      hour: 18,
      title: '🇰🇷 J-news 한국 브리핑',
      body: '오늘의 한국 주요 뉴스가 준비되었습니다. 확인해보세요!',
      payload: 'kr',
    );
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'news_briefing',
          'J-news',
          channelDescription: '매일 뉴스 요약 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }
}
