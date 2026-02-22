import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static NotificationTapCallback? onTap;

  static Future<void> init({NotificationTapCallback? onNotificationTap}) async {
    onTap = onNotificationTap;

    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // POST_NOTIFICATIONS 권한만 여기서 요청 (Android 13+)
    // SCHEDULE_EXACT_ALARM은 스케줄 등록 시 자동으로 체크해서 처리
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    onTap?.call(response.payload);
  }

  /// 현재 알림 권한 상태 반환
  static Future<Map<String, bool>> getPermissionStatus() async {
    if (!Platform.isAndroid) {
      return {'notification': true, 'exactAlarm': true, 'batteryOptimization': true};
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final notification = await androidPlugin?.areNotificationsEnabled() ?? false;
    final exactAlarm = await androidPlugin?.canScheduleExactNotifications() ?? false;
    final batteryOptIgnored = await Permission.ignoreBatteryOptimizations.isGranted;

    return {
      'notification': notification,
      'exactAlarm': exactAlarm,
      'batteryOptimization': batteryOptIgnored,
    };
  }

  /// 알림 권한 요청 (앱 정보 화면 등에서 명시적으로 호출)
  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await Permission.ignoreBatteryOptimizations.request();
  }

  /// 즉시 테스트 알림 전송
  static Future<void> sendTestNotification() async {
    await _plugin.show(
      id: 99,
      title: '🔔 J-news 알림 테스트',
      body: '알림이 정상적으로 작동하고 있어요!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'news_briefing',
          'J-news 뉴스 브리핑',
          channelDescription: '평일 뉴스 요약 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> scheduleDailyNews() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[J-news] cancelAll 실패: $e');
    }

    // 정확한 알람 권한 여부 확인 → 없으면 inexact로 fallback
    bool canExact = false;
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      canExact = await androidPlugin?.canScheduleExactNotifications() ?? false;
    } else {
      canExact = true;
    }

    debugPrint('[J-news] 정확한 알람 권한: $canExact');

    // 화~토 오전 8시 - 미국 뉴스 (id 0~4)
    final usWeekdays = [
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ];
    for (int i = 0; i < usWeekdays.length; i++) {
      await _scheduleWeekday(
        id: i,
        hour: 8,
        weekday: usWeekdays[i],
        title: '🇺🇸 미국 뉴스 브리핑',
        body: '오늘의 미국 주요 뉴스가 준비되었습니다.',
        payload: 'us',
        useExactAlarm: canExact,
      );
    }

    // 월~금 오후 6시 - 한국 뉴스 (id 5~9)
    for (int weekday = DateTime.monday; weekday <= DateTime.friday; weekday++) {
      await _scheduleWeekday(
        id: weekday + 4,
        hour: 18,
        weekday: weekday,
        title: '🇰🇷 한국 뉴스 브리핑',
        body: '오늘의 한국 주요 뉴스가 준비되었습니다.',
        payload: 'kr',
        useExactAlarm: canExact,
      );
    }

    debugPrint('[J-news] 알림 스케줄 등록 완료 (US: 화~토 08:00 / KR: 월~금 18:00)');
  }

  static Future<void> _scheduleWeekday({
    required int id,
    required int hour,
    required int weekday,
    required String title,
    required String body,
    required bool useExactAlarm,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);

    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'news_briefing',
            'J-news 뉴스 브리핑',
            channelDescription: '평일 뉴스 요약 알림',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: useExactAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
      debugPrint('[J-news] 알림 등록 (id=$id, ${scheduled.toString()})');
    } catch (e) {
      debugPrint('[J-news] 알림 스케줄 실패 (id=$id): $e');
    }
  }
}
