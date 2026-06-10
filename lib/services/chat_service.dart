import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

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
    final body = jsonEncode({
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
