import 'package:shared_preferences/shared_preferences.dart';

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

    await prefs.setString(_tokenKey, cleanToken);
    await prefs.setInt(_userIdKey, userId); // ✅ STORE AS INT
    await prefs.setString(_roleKey, role.toLowerCase());
  }

  /// ✅ Get JWT for authenticated requests
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// ✅ Get logged-in user ID (INT)
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey); // ✅ RETURN INT
  }

  /// ✅ Get logged-in user role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  /// ✅ Clear ALL auth data (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }
}
