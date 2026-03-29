import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class NotificationApiService {
  static Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    int? eventId,
  }) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final query = Uri.parse("${ApiConfig.baseUrl}/notifications").replace(
      queryParameters: {
        "page": page.toString(),
        "limit": limit.toString(),
        if (type != null && type.trim().isNotEmpty) "type": type.trim(),
        if (eventId != null) "eventId": eventId.toString(),
      },
    );

    final res = await http.get(
      query,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to fetch notifications");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> clearNotifications() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final res = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/notifications"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to clear notifications");
    }
  }

  static Future<void> markRead(String id) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final res = await http.patch(
      Uri.parse("${ApiConfig.baseUrl}/notifications/$id/read"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to mark notification read");
    }
  }

  static Future<void> markAllRead() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/notifications/read-all"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to mark all read");
    }
  }

  static Future<int> fetchUnreadCount() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/notifications/unread-count"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to fetch unread count");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data["unreadCount"] as num?)?.toInt() ?? 0;
  }
}
