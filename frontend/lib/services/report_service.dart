import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class ReportService {
  static Future<void> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? details,
  }) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/reports"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "targetType": targetType,
        "targetId": targetId,
        "reason": reason,
        if (details != null) "details": details,
      }),
    );

    if (response.statusCode != 201) {
      String error = "Failed to submit report";
      try {
        final data = jsonDecode(response.body);
        error =
            data["error"]?.toString() ??
            data["message"]?.toString() ??
            error;
      } catch (_) {}

      if (error == "Failed to submit report") {
        final rawBody = response.body.trim();
        if (rawBody.isNotEmpty) {
          error = "Failed to submit report (${response.statusCode}): $rawBody";
        } else {
          error = "Failed to submit report (${response.statusCode})";
        }
      }

      throw Exception(error);
    }
  }

  static Future<Map<String, dynamic>> getMyReports({
    int page = 1,
    int limit = 20,
    String status = 'all',
    String type = 'all',
  }) async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found");
    }

    final query = Uri.parse(
      "${ApiConfig.baseUrl}/reports/me?page=$page&limit=$limit&status=$status&type=$type",
    );

    final response = await http.get(
      query,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode != 200) {
      String error = "Failed to load reports";
      try {
        final data = jsonDecode(response.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }

    return jsonDecode(response.body);
  }
}
