import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class ChatService {
  static Future<Map<String, dynamic>> getOrCreateThread({
    required int eventId,
    int? volunteerId,
  }) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final body = {
      "eventId": eventId,
      if (volunteerId != null) "volunteerId": volunteerId,
    };

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/chat/thread"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception("Failed to create chat thread: ${response.body}");
  }

  static Future<List<dynamic>> fetchMessages(int threadId) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/chat/thread/$threadId/messages"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data["messages"] as List<dynamic>?) ?? [];
    }

    throw Exception("Failed to fetch messages");
  }

  static String socketUrl() {
    return ApiConfig.baseUrl.replaceAll("/api", "");
  }

  static Future<List<dynamic>> fetchThreads() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/chat/threads"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception("Failed to fetch threads");
  }
}
