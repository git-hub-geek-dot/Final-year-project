import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class RatingService {
  static Future<void> submitRating({
    required int eventId,
    required int rateeId,
    required int score,
    String? comment,
  }) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/ratings"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "event_id": eventId,
        "ratee_id": rateeId,
        "score": score,
        "comment": comment,
      }),
    );

    if (response.statusCode != 201) {
      final body = response.body.isNotEmpty ? response.body : "";
      throw Exception("Failed to submit rating: $body");
    }
  }

  static Future<Map<String, dynamic>> fetchSummary(int userId) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/ratings/$userId/summary"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Failed to fetch rating summary");
  }
}
