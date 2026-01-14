import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String _tokenKey = 'jwt_token';

  /// Save JWT after login (fully cleaned)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = token.replaceAll(RegExp(r'\s+'), '');
    await prefs.setString(_tokenKey, clean);
  }

  /// Get JWT for authenticated requests
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clear JWT on logout
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
