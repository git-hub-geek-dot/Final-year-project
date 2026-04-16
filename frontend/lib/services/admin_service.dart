import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../config/api_config.dart';

class AdminService {
  // ================= EVENTS =================
  static Future<Map<String, dynamic>> getAllEvents(
      {int page = 1, int limit = 20}) async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/events?page=$page&limit=$limit"),
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

  static Future<void> hardDeleteEvent(int eventId) async {
    final token = await TokenService.getToken();

    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/admin/events/$eventId/hard"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to permanently delete event");
    }
  }

  static Future<void> restoreEvent(int eventId, String status) async {
    final token = await TokenService.getToken();

    final response = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/admin/events/$eventId/restore"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"status": status}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to restore event");
    }
  }

  // ================= USERS =================
  static Future<Map<String, dynamic>> getAllUsers(
      {int page = 1, int limit = 20}) async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/users?page=$page&limit=$limit"),
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

  static Future<Map<String, dynamic>> addUserStrike(
    int userId,
    String reason,
  ) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/strikes"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"reason": reason}),
    );

    if (res.statusCode != 200) {
      String message = "Failed to add strike";
      try {
        final data = jsonDecode(res.body);
        message = data["error"]?.toString() ?? message;
      } catch (_) {}
      throw Exception(message);
    }

    return jsonDecode(res.body);
  }

  static Future<void> resetUserStrikes(int userId) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/strikes/reset"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to reset strikes");
    }
  }

  static Future<void> suspendUser(
    int userId,
    int days,
    String reason,
  ) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/suspend"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"days": days, "reason": reason}),
    );

    if (res.statusCode != 200) {
      String message = "Failed to suspend user";
      try {
        final data = jsonDecode(res.body);
        message = data["error"]?.toString() ?? message;
      } catch (_) {}
      throw Exception(message);
    }
  }

  static Future<void> unsuspendUser(int userId) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/unsuspend"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to unsuspend user");
    }
  }

  // ================= APPLICATIONS =================
  static Future<Map<String, dynamic>> getAllApplications({
    int page = 1,
    int limit = 20,
    int? eventId,
  }) async {
    final token = await TokenService.getToken();
    final uri = Uri.parse("${ApiConfig.baseUrl}/admin/applications").replace(
      queryParameters: {
        "page": "$page",
        "limit": "$limit",
        if (eventId != null) "eventId": "$eventId",
      },
    );

    final res = await http.get(
      uri,
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

  static Future<void> cancelApplication(int appId, String reason) async {
    final token = await TokenService.getToken();

    final res = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/admin/applications/$appId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"reason": reason}),
    );

    if (res.statusCode != 200) {
      String message = "Failed to cancel application";
      try {
        final data = jsonDecode(res.body);
        message = data["error"]?.toString() ?? message;
      } catch (_) {}
      throw Exception(message);
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

  static Future<List<dynamic>> getStatsTimeseries({int days = 7}) async {
    final token = await TokenService.getToken();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/stats/timeseries?days=$days"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load stats timeseries");
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
    if (res.statusCode != 200) {
      throw Exception("Failed to load badges");
    }
    return jsonDecode(res.body);
  }

  static Future<void> createBadge(Map<String, dynamic> body) async {
    final token = await TokenService.getToken();
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/badges"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String error = "Failed to create badge";
      try {
        final data = jsonDecode(response.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }
  }

  static Future<void> deleteBadge(int badgeId) async {
    final token = await TokenService.getToken();
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/admin/badges/$badgeId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to delete badge");
    }
  }

  static Future<List<dynamic>> getUserBadges() async {
    final token = await TokenService.getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/admin/badges/users"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) {
      throw Exception("Failed to load user badges");
    }
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

  // ================= BROADCAST NOTIFICATIONS =================
  static Future<void> sendBroadcastNotification({
    required String title,
    required String message,
    String targetRole = 'all',
  }) async {
    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/notifications/broadcast"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "message": message,
        "targetRole": targetRole,
      }),
    );

    if (response.statusCode != 200) {
      String error = "Failed to send broadcast notification";
      try {
        final data = jsonDecode(response.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }
  }

  static Future<void> updateUserNote(int userId, String note) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/note"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"note": note}),
    );

    if (res.statusCode != 200) {
      String message = "Failed to update note";
      try {
        final data = jsonDecode(res.body);
        message = data["error"]?.toString() ?? message;
      } catch (_) {}
      throw Exception(message);
    }
  }

  // ================= TARGETED NOTIFICATIONS =================
  static Future<void> sendTargetedNotification({
    required List<int> userIds,
    required String title,
    required String message,
  }) async {
    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/notifications/users"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "userIds": userIds,
        "title": title,
        "message": message,
      }),
    );

    if (response.statusCode != 200) {
      String error = "Failed to send targeted notification";
      try {
        final data = jsonDecode(response.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }
  }

  static Future<void> sendEventNotification({
    required int eventId,
    required String title,
    required String message,
  }) async {
    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/notifications/event"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "eventId": eventId,
        "title": title,
        "message": message,
      }),
    );

    if (response.statusCode != 200) {
      String error = "Failed to send event notification";
      try {
        final data = jsonDecode(response.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }
  }

  // ================= REPORTS =================
  static Future<Map<String, dynamic>> getReports({
    int page = 1,
    int limit = 20,
    String status = 'pending',
    String type = 'all',
    String search = '',
  }) async {
    final token = await TokenService.getToken();
    final query = Uri.parse(
      "${ApiConfig.baseUrl}/admin/reports?page=$page&limit=$limit&status=$status&type=$type&search=${Uri.encodeComponent(search)}",
    );

    final res = await http.get(
      query,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load reports");
    }

    return jsonDecode(res.body);
  }

  static Future<void> dismissReport({
    required int reportId,
    String note = '',
  }) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/reports/$reportId/dismiss"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"note": note}),
    );

    if (res.statusCode != 200) {
      String error = "Failed to dismiss report";
      try {
        final data = jsonDecode(res.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }
  }

  static Future<void> resolveReport({
    required int reportId,
    required String action,
    String note = '',
    String? strikeReason,
    int? suspendDays,
    String? suspendReason,
    String? cancelReason,
  }) async {
    final token = await TokenService.getToken();

    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/admin/reports/$reportId/resolve"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "action": action,
        "note": note,
        if (strikeReason != null) "strikeReason": strikeReason,
        if (suspendDays != null) "suspendDays": suspendDays,
        if (suspendReason != null) "suspendReason": suspendReason,
        if (cancelReason != null) "cancelReason": cancelReason,
      }),
    );

    if (res.statusCode != 200) {
      String error = "Failed to resolve report";
      try {
        final data = jsonDecode(res.body);
        error = data["error"]?.toString() ?? error;
      } catch (_) {}
      throw Exception(error);
    }
  }
}
