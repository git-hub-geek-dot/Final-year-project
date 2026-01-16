import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../config/api_config.dart';

class AdminService {
  // ================= EVENTS =================
  static Future<List<dynamic>> getAllEvents() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/events"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load events");
    }

    return jsonDecode(response.body);
  }

  static Future<void> deleteEvent(int eventId) async {
    final token = await TokenService.getToken();

    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/admin/events/$eventId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete event");
    }
  }

  // ================= USERS =================
  static Future<List<dynamic>> getAllUsers() async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/users"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load users");
    }

    return jsonDecode(res.body);
  }

  static Future<void> updateUserStatus(int userId, String status) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/status"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"status": status}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update status");
    }
  }

  // ================= APPLICATIONS =================
  static Future<List<dynamic>> getAllApplications() async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/applications"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load applications");
    }

    return jsonDecode(res.body);
  }

  static Future<void> cancelApplication(int appId) async {
    final token = await TokenService.getToken();

    final res = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/admin/applications/$appId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to cancel application");
    }
  }

  // ================= STATS =================
  static Future<Map<String, dynamic>> getStats() async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/stats"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load stats");
    }

    return jsonDecode(res.body);
  }

  // ================= LEADERBOARD =================
  static Future<List<dynamic>> getVolunteerLeaderboard() async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/leaderboard/volunteers"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load volunteer leaderboard");
    }

    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getOrganiserLeaderboard() async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/leaderboard/organisers"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load organiser leaderboard");
    }

    return jsonDecode(res.body);
  }

  // ================= BADGES =================
  static Future<List<dynamic>> getBadges() async {
    final token = await TokenService.getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/badges"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(res.body);
  }

  static Future<void> createBadge(Map<String, dynamic> body) async {
    final token = await TokenService.getToken();
    await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/badges"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
  }

  static Future<List<dynamic>> getUserBadges() async {
    final token = await TokenService.getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/badges/users"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(res.body);
  }

  // =================================================
  // ========== VERIFICATION (NEW - SAFE) =============
  // =================================================

  // Fetch all verification requests
  static Future<List<dynamic>> getVerificationRequests() async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/verification-requests"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load verification requests");
    }

    return jsonDecode(res.body);
  }

  // Approve verification
  static Future<void> approveVerification(int requestId) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/verification/approve"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"requestId": requestId}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to approve verification");
    }
  }

  // Reject verification
  static Future<void> rejectVerification(
    int requestId,
    String remark,
  ) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/verification/reject"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "requestId": requestId,
        "remark": remark,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to reject verification");
    }
  }
}
