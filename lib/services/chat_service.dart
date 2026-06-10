import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

/// 일일 사용량 한도 초과 (HTTP 429 + error: daily_limit)
class ChatDailyLimitException implements Exception {
  final String message;
  const ChatDailyLimitException(this.message);

  @override
  String toString() => message;
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime ts;

  const ChatMessage({required this.role, required this.content, required this.ts});

  bool get isUser => role == 'user';

  Map<String, dynamic> toApiJson() => {
        'role': role,
        'content': content,
      };
}

class ChatService {
  static const Duration _timeout = Duration(seconds: 25);

  /// news_context: {title, body} (현재 보고 있는 뉴스)
  /// history: 이전 대화
  /// message: 최신 유저 메시지
  /// 반환: AI 응답 문자열
  static Future<String> sendMessage({
    Map<String, dynamic>? newsContext,
    required List<ChatMessage> history,
    required String message,
  }) async {
    final uid = AuthService.uid;
    final body = jsonEncode({
      if (uid != null) 'uid': uid,
      if (newsContext != null) 'news_context': newsContext,
      'history': history.map((m) => m.toApiJson()).toList(),
      'message': message,
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } catch (e) {
      throw Exception('AI에 연결할 수 없어. 네트워크 확인해줘.');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = (data['reply'] ?? '').toString().trim();
        if (reply.isEmpty) throw Exception('AI 응답이 비어 있어.');
        return reply;
      } catch (e) {
        throw Exception('AI 응답을 처리하지 못했어.');
      }
    } else if (response.statusCode == 429) {
      // 일일 한도 초과(daily_limit) vs 분당 rate limit 구분
      try {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        if (error['error'] == 'daily_limit') {
          throw ChatDailyLimitException(
            (error['message'] ?? '오늘 AI 튜터 사용량을 다 썼어요. 내일 다시 만나요!').toString(),
          );
        }
      } on ChatDailyLimitException {
        rethrow;
      } catch (_) {
        // JSON 파싱 실패 → 일반 rate limit 처리
      }
      throw Exception('잠시 후 다시 시도해줘. (요청이 너무 많아)');
    } else {
      try {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? 'AI 응답 실패');
      } catch (_) {
        throw Exception('서버 오류 (${response.statusCode})');
      }
    }
  }
}
