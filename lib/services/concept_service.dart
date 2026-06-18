import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

/// 토픽(domain)별 mastery 진척.
class DomainProgress {
  final String domain;
  final int total;
  final int mastered;
  final double ratio;

  const DomainProgress({
    required this.domain,
    required this.total,
    required this.mastered,
    required this.ratio,
  });

  factory DomainProgress.fromJson(Map<String, dynamic> j) => DomainProgress(
        domain: j['domain'] ?? 'etc',
        total: (j['total'] as num?)?.toInt() ?? 0,
        mastered: (j['mastered'] as num?)?.toInt() ?? 0,
        ratio: (j['ratio'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 유저의 개념 학습 진척 (완독보너스 자리 viz 데이터).
class ConceptProgress {
  final int encountered; // 만난 개념
  final int mastered; // 습득 완료
  final int learning; // 학습 중
  final int dueToday; // 오늘 복습할 것
  final List<DomainProgress> domains;

  const ConceptProgress({
    required this.encountered,
    required this.mastered,
    required this.learning,
    required this.dueToday,
    required this.domains,
  });

  static const empty = ConceptProgress(
    encountered: 0, mastered: 0, learning: 0, dueToday: 0, domains: [],
  );

  bool get isEmpty => encountered == 0 && mastered == 0;

  factory ConceptProgress.fromJson(Map<String, dynamic> j) => ConceptProgress(
        encountered: (j['encountered'] as num?)?.toInt() ?? 0,
        mastered: (j['mastered'] as num?)?.toInt() ?? 0,
        learning: (j['learning'] as num?)?.toInt() ?? 0,
        dueToday: (j['due_today'] as num?)?.toInt() ?? 0,
        domains: (j['domains'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(DomainProgress.fromJson)
                .toList() ??
            const [],
      );
}

/// 개념 학습 신호 기록 + 진척 조회.
/// 모든 호출은 실패해도 앱 흐름을 막지 않음(fail-soft).
class ConceptService {
  static const Duration _timeout = Duration(seconds: 8);
  static String get _url => '${ApiService.baseUrl}/api/concepts';

  /// 카드 노출(패시브). fire-and-forget. uid 없으면 IP fallback(서버 처리).
  static Future<void> recordExposure(List<int> conceptIds) async {
    if (conceptIds.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'exposure',
              if (AuthService.uid != null) 'uid': AuthService.uid,
              'concept_ids': conceptIds,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[ConceptService] exposure 실패(무시): $e');
    }
  }

  /// 퀴즈/복습 결과(액티브 — Leitner 승급). 갱신 진척 반환(실패 시 null).
  static Future<ConceptProgress?> recordReview(int conceptId, bool correct) async {
    try {
      final res = await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'review',
              if (AuthService.uid != null) 'uid': AuthService.uid,
              'concept_id': conceptId,
              'correct': correct,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final prog = data['progress'];
        if (prog is Map<String, dynamic>) return ConceptProgress.fromJson(prog);
      }
    } catch (e) {
      debugPrint('[ConceptService] review 실패(무시): $e');
    }
    return null;
  }

  /// 진척 조회. 실패 시 null.
  static Future<ConceptProgress?> getProgress() async {
    final uid = AuthService.uid;
    if (uid == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$_url?uid=$uid'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return ConceptProgress.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint('[ConceptService] progress 실패(무시): $e');
    }
    return null;
  }
}
