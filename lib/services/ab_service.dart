import 'dart:convert';

/// A/B 코호트 분배 (개념 진척 viz on/off 검증).
///
/// - A = viz ON (처치군), B = viz OFF (대조군 = viz 추가 전 동작)
/// - uid 기반 결정적 분배 → 같은 유저는 항상 같은 군. 50/50.
/// - FNV-1a 32bit 해시 — Python 서버와 동일 알고리즘(파리티 필요 시 재현 가능).
class AbService {
  /// FNV-1a 32-bit. utf8 바이트 순회. Dart int는 64bit라 곱셈 후 마스킹으로 32bit 유지.
  static int _fnv1a(String s) {
    int hash = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// 'A'(viz on) 또는 'B'(viz off). uid 없으면 'A'(노출, 로그인 필수 흐름이라 사실상 미발생).
  static String cohort(String? uid) {
    if (uid == null || uid.isEmpty) return 'A';
    return _fnv1a(uid) % 2 == 0 ? 'A' : 'B';
  }

  /// 개념 진척 viz 노출 여부 (A군만).
  static bool vizEnabled(String? uid) => cohort(uid) == 'A';
}
