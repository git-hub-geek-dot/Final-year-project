import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class BadgeService {
  static Future<Map<String, dynamic>> fetchMyBadges() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/users/me/badges"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch badges");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
