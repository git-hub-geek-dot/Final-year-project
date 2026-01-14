import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userId';

  /// ✅ Save JWT + User ID after login
  static Future<void> saveAuthData({
    required String token,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Ensure token is clean (no whitespace / line breaks)
    final cleanToken = token.replaceAll(RegExp(r'\s+'), '');

    await prefs.setString(_tokenKey, cleanToken);
    await prefs.setString(_userIdKey, userId);
  }

  /// ✅ Get JWT for authenticated requests
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// ✅ Get logged-in user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// ✅ Clear ALL auth data (logout)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
}
