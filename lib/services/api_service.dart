import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_result.dart';

class ApiService {
  static const String _baseUrl = 'https://backend-ruby-chi-85.vercel.app';
  static const Duration _timeout = Duration(seconds: 15);

  static Future<NewsResult> getNewsSummary(String region, {String category = 'general'}) async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$_baseUrl/api/news?region=$region&category=$category'),
      ).timeout(_timeout);
    } catch (e) {
      throw Exception('서버에 연결할 수 없습니다. 네트워크를 확인해주세요.');
    }

    if (response.statusCode == 200) {
      try {
        return NewsResult.fromJson(jsonDecode(response.body));
      } catch (e) {
        throw Exception('뉴스 데이터를 처리하는 중 오류가 발생했습니다.');
      }
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '뉴스를 가져오지 못했습니다.');
      } catch (e) {
        if (e is Exception && e.toString().contains('detail')) rethrow;
        throw Exception('서버 오류가 발생했습니다. (${response.statusCode})');
      }
    }
  }
}
