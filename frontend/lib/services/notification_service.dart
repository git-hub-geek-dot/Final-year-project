import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class NotificationService {
  static Future<void> init() async {
    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onTokenRefresh.listen((token) async {
      await _sendTokenToBackend(token);
    });
  }

  static Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _sendTokenToBackend(token);
  }

  static Future<void> _sendTokenToBackend(String token) async {
    final jwt = await TokenService.getToken();
    if (jwt == null || jwt.isEmpty) {
      return;
    }

    await http.post(
      Uri.parse("${ApiConfig.baseUrl}/notifications/register-token"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $jwt",
      },
      body: jsonEncode({
        "token": token,
        "platform": "android",
      }),
    );
  }
}
