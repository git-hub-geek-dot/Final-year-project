import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  // 🔐 LOGIN
  Future<Map<String, dynamic>> login(
      String email, String password) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/login");

    print("CALLING LOGIN API: $url");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    print("LOGIN STATUS: ${response.statusCode}");
    print("LOGIN BODY: ${response.body}");

    return jsonDecode(response.body);
  }

  // 📝 REGISTER
  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/register");

    print("CALLING REGISTER API: $url");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );

    print("REGISTER STATUS: ${response.statusCode}");
    print("REGISTER BODY: ${response.body}");

    return jsonDecode(response.body);
  }
}
