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

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'news_briefing',
      'J-news 뉴스 브리핑',
      channelDescription: '매일 뉴스 요약 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

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
    // 권한 요청은 onboarding 의 opt-in 체크박스 이후에만 실행
  }

  static void _onNotificationTap(NotificationResponse response) {
    onTap?.call(response.payload);
  }

  static Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
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
  /// 알림(POST_NOTIFICATIONS, Android 13+) 권한만 요청.
  /// SCHEDULE_EXACT_ALARM은 시스템 설정 페이지를 열어 UX가 나쁨 →
  /// inexact 알람으로 fallback (7시/18시 푸시는 분 단위 오차 무관).
  /// 반환값: 허용되면 true, 거부되면 false (iOS는 항상 true 가정).
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 즉시 테스트 알림 전송
  static Future<void> sendTestNotification() async {
    await _plugin.show(
      id: 99,
      title: '🔔 J-news 알림 테스트',
      body: '알림이 정상적으로 작동하고 있어요!',
      notificationDetails: _notificationDetails,
    );
  }

  static Future<void> scheduleDailyNews() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[J-news] cancelAll 실패: $e');
    }

    final canExact = await _canScheduleExact();

    // 오전 7시 매일 알림 (id 0)
    await _scheduleDaily(
      id: 0,
      hour: 7,
      title: 'J-NEWS 브리핑',
      body: '오늘의 주요 뉴스가 준비됐어요.',
      payload: 'briefing_morning',
      useExactAlarm: canExact,
    );

    // 오후 6시 매일 알림 (id 1)
    await _scheduleDaily(
      id: 1,
      hour: 18,
      title: 'J-NEWS 저녁 브리핑',
      body: '오늘 저녁 주요 뉴스가 준비됐어요.',
      payload: 'briefing_evening',
      useExactAlarm: canExact,
    );

    debugPrint('[J-news] 알림 스케줄 등록 완료 (매일 07:00 / 18:00)');
  }

  /// 앱에서 뉴스 로드 후 첫 번째 뉴스 제목으로 알림 내용 업데이트 (아침/저녁 모두)
  static Future<void> updateNotificationWithNews(String topNewsTitle) async {
    final canExact = await _canScheduleExact();
    final body = topNewsTitle.length > 50
        ? '${topNewsTitle.substring(0, 47)}...'
        : topNewsTitle;

    await _scheduleDaily(
      id: 0,
      hour: 7,
      title: 'J-NEWS 브리핑',
      body: body,
      payload: 'briefing_morning',
      useExactAlarm: canExact,
    );
    await _scheduleDaily(
      id: 1,
      hour: 18,
      title: 'J-NEWS 저녁 브리핑',
      body: body,
      payload: 'briefing_evening',
      useExactAlarm: canExact,
    );
    debugPrint('[J-news] 알림 내용 업데이트 (morning + evening): $body');
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
    required bool useExactAlarm,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);

    // 오늘 시간이 이미 지났으면 내일로
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: useExactAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시간에 반복
        payload: payload,
      );
      debugPrint('[J-news] 알림 등록 (id=$id, ${scheduled.toString()})');
    } catch (e) {
      debugPrint('[J-news] 알림 스케줄 실패 (id=$id): $e');
    }
  }
}
