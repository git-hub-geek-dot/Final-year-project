import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'token_service.dart';

class VerificationService {
  static Future<String?> getStatus() async {
    final token = await TokenService.getToken();
    if (token == null) return null;

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/verification/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["status"]; // pending / approved / rejected
    }
    return null;
  }
}
