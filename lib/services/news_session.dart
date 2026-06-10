/// KST 기반 뉴스 세션 타이밍 헬퍼.
/// 세션 경계:
///   07:00~11:59 → morning
///   12:00~17:59 → noon
///   18:00~23:59 → evening (오늘 날짜)
///   00:00~06:59 → evening (어제 날짜) — 새벽은 전일 evening 연장
class NewsSession {
  NewsSession._();

  static String _dateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// KST 기준 현재 세션 키.
  static String currentSessionKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final hour = kst.hour;
    if (hour >= 18) {
      return '${_dateStr(kst)}_evening';
    }
    if (hour < 7) {
      final yesterday = kst.subtract(const Duration(days: 1));
      return '${_dateStr(yesterday)}_evening';
    }
    if (hour < 12) {
      return '${_dateStr(kst)}_morning';
    }
    return '${_dateStr(kst)}_noon';
  }

  /// 현재 세션 라벨 (UI 표시용)
  static String currentSessionLabel() {
    final key = currentSessionKey();
    if (key.endsWith('_morning')) return '오전';
    if (key.endsWith('_noon')) return '낮';
    return '저녁';
  }

  /// 다음 세션 시작 시각 (KST 기준 DateTime).
  /// 경계: 07:00 morning, 12:00 noon, 18:00 evening, 다음날 07:00 morning.
  static DateTime nextSessionBoundaryKst() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final h = kst.hour;
    DateTime build(int hour, {int dayOffset = 0}) =>
        DateTime(kst.year, kst.month, kst.day + dayOffset, hour);
    if (h < 7) return build(7);
    if (h < 12) return build(12);
    if (h < 18) return build(18);
    return build(7, dayOffset: 1);
  }

  /// 다음 세션 라벨 ('오전'|'낮'|'저녁')
  static String nextSessionLabel() {
    final next = nextSessionBoundaryKst();
    final h = next.hour;
    if (h == 7) return '오전';
    if (h == 12) return '낮';
    return '저녁';
  }

  /// 다음 세션까지 남은 시간 표시 ("4시간 12분", "32분" 등)
  static String nextSessionCountdown() {
    final kstNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    final boundary = nextSessionBoundaryKst();
    final diff = boundary.difference(kstNow);
    if (diff.isNegative) return '곧 갱신';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours == 0) return '$minutes분';
    return '$hours시간 $minutes분';
  }
}
