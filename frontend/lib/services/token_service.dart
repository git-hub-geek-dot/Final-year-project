import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'session_manager.dart';

class TokenService {
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'user_id';
  static const String _roleKey = 'user_role';

  /// ✅ Save JWT + User ID after login
  static Future<void> saveAuthData({
    required String token,
    required int userId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Clean token (safety)
    final cleanToken = token.replaceAll(RegExp(r'\s+'), '');

    SessionManager.reset();
    await prefs.setString(_tokenKey, cleanToken);
    await prefs.setInt(_userIdKey, userId); // ✅ STORE AS INT
    await prefs.setString(_roleKey, role.toLowerCase());
  }

  /// ✅ Get JWT for authenticated requests
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    if (_isTokenExpired(token)) {
      SessionManager.notifySessionExpired();
      await clearToken();
      return null;
    }

    return token;
  }

  /// ✅ Get logged-in user ID (INT)
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    if (token == null) {
      return null;
    }
    return prefs.getInt(_userIdKey); // ✅ RETURN INT
  }

  /// ✅ Get logged-in user role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    if (token == null) {
      return null;
    }
    return prefs.getString(_roleKey);
  }

  /// ✅ Clear ALL auth data (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }

  static bool _isTokenExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return true;
    }

    try {
      final payloadJson = _decodeBase64Url(parts[1]);
      final payload = json.decode(payloadJson);
      if (payload is! Map || !payload.containsKey('exp')) {
        return true;
      }

      final exp = payload['exp'];
      if (exp is! num) {
        return true;
      }

      final expiryMs = exp.toInt() * 1000;
      return DateTime.now().millisecondsSinceEpoch >= expiryMs;
    } catch (_) {
      return true;
    }
  }

  static String _decodeBase64Url(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 0:
        break;
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
      default:
        return '';
    }
    return utf8.decode(base64.decode(normalized));
  }
}
