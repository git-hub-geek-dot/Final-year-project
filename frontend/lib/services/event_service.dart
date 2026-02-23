import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';
import 'package:image_picker/image_picker.dart'; // for XFile

class EventService {
  /// 🔼 Upload image (Web + Mobile) and return public URL
  static Future<String> uploadImage(XFile file) async {
    final token = await TokenService.getToken();
    if (token == null) {
      throw Exception("No token found");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("${ApiConfig.baseUrl}/upload"),
    );

    request.headers["Authorization"] = "Bearer $token";

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          bytes,
          filename: file.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath("image", file.path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["url"];
    } else {
      throw Exception("Image upload failed: ${response.body}");
    }
  }

  /// ================= CREATE EVENT =================
  static Future<bool> createEvent({
    required String title,
    String? description,
    String? location,
    String? eventDate,
    String? endDate,
    String? applicationDeadline,
    int? volunteersRequired,
    String? eventType,
    double? paymentPerDay,
    String? bannerUrl,
    List<String>? categories,
    List<String>? responsibilities,
    String? startTime,
    String? endTime,
    bool isDraft = false,
    List<Map<String, dynamic>>? dailySchedules,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) {
      throw Exception("No token found");
    }

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/events"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
        "location": location,
        "event_date": eventDate,
        "end_date": endDate,
        "application_deadline": applicationDeadline,
        "volunteers_required": volunteersRequired,
        "event_type": eventType,
        "payment_per_day": eventType == "paid" ? paymentPerDay : null,
        "banner_url": bannerUrl,
        "categories": categories ?? [],
        "responsibilities": responsibilities ?? [],
        "start_time": startTime,
        "end_time": endTime,
        "is_draft": isDraft,
        "daily_schedules": dailySchedules ?? [],
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      print("CREATE EVENT ERROR → ${response.body}");
      return false;
    }
  }

  /// ================= MY EVENTS =================
  static Future<List<dynamic>> fetchMyEvents() async {
    final token = await TokenService.getToken();
    if (token == null) {
      throw Exception("No token found");
    }

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/events/my-events"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("FETCH EVENTS ERROR → ${response.body}");
      throw Exception("Failed to fetch organiser events");
    }
  }

  /// ================= ALL EVENTS (PUBLIC) =================
  static Future<List<dynamic>> fetchAllEvents() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/events"),
      headers: {
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("FETCH ALL EVENTS ERROR → ${response.body}");
      throw Exception("Failed to fetch all events");
    }
  }

  /// ================= EVENT DETAILS =================
  static Future<Map<String, dynamic>> fetchEventById(int eventId) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      headers: {
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch event details");
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception("Invalid event details response");
  }

  /// ================= APPLICATIONS =================
  static Future<List<dynamic>> fetchApplications(int eventId) async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/events/$eventId/applications"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch applications");
    }
  }

  /// ================= UPDATE EVENT =================
  static Future<bool> updateEvent({
    required int id,
    required String title,
    required String description,
    required String location,
    required String eventDate,
    required String endDate,
    required String applicationDeadline,
    required int volunteersRequired,
    required String eventType,
    double? paymentPerDay,
    String? bannerUrl,
    List<String>? categories,
    List<String>? responsibilities,
    String? startTime,
    String? endTime,
    bool publish = false,
    List<Map<String, dynamic>>? dailySchedules,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) throw Exception("No token");

    final response = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/events/$id"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
        "location": location,
        "event_date": eventDate,
        "end_date": endDate,
        "application_deadline": applicationDeadline,
        "volunteers_required": volunteersRequired,
        "event_type": eventType,
        "payment_per_day": eventType == "paid" ? paymentPerDay : null,
        "banner_url": bannerUrl,
        "categories": categories ?? [],
        "responsibilities": responsibilities ?? [],
        "start_time": startTime,
        "end_time": endTime,
        "publish": publish,
        "daily_schedules": dailySchedules ?? [],
      }),
    );

    return response.statusCode == 200;
  }

  /// ================= CANCEL EVENT =================
  static Future<void> cancelEvent({
    required int id,
    required String reason,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) throw Exception("No token");

    final response = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/events/$id/cancel"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "reason": reason,
      }),
    );

    if (response.statusCode == 200) return;

    String message = "Failed to cancel event";
    try {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final parsed = data["error"] ?? data["message"];
        if (parsed != null && parsed.toString().trim().isNotEmpty) {
          message = parsed.toString();
        }
      }
    } catch (_) {}

    throw Exception(message);
  }

  /// ================= ANNOUNCE EVENT =================
  static Future<int> announceEvent({
    required int id,
    required String message,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) throw Exception("No token");

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception("Announcement message is required");
    }

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/events/$id/announce"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "message": trimmedMessage,
      }),
    );

    if (response.statusCode == 200) {
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["recipients"] is num) {
          return (decoded["recipients"] as num).toInt();
        }
      } catch (_) {}
      return 0;
    }

    String errorMessage = "Failed to send announcement";
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final parsed = decoded["error"] ?? decoded["message"];
        if (parsed != null && parsed.toString().trim().isNotEmpty) {
          errorMessage = parsed.toString();
        }
      }
    } catch (_) {}

    throw Exception(errorMessage);
  }

  /// ================= PUBLISH DRAFT =================
  static Future<void> publishDraftEvent(int id) async {
    final token = await TokenService.getToken();
    if (token == null) throw Exception("No token");

    final response = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/events/$id/publish"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) return;

    String? parsedMessage;
    try {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final message =
            data["error"] ?? data["message"] ?? "Failed to publish event";
        final missing = data["missing_fields"];
        if (missing is List && missing.isNotEmpty) {
          parsedMessage = "$message: ${missing.join(', ')}";
        } else {
          parsedMessage = message.toString();
        }
      }
    } catch (_) {
      // Fallback below
    }

    throw Exception(parsedMessage ?? "Failed to publish event");
  }

  /// ================= LEADERBOARD =================
  static Future<List<dynamic>> fetchLeaderboard({
    required String role,
    required String period,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) throw Exception("No token");

    final safeRole = role == "volunteers" ? "volunteers" : "organisers";
    final safePeriod = period == "weekly" ? "weekly" : "monthly";

    final response = await http.get(
      Uri.parse(
        "${ApiConfig.baseUrl}/events/leaderboard/$safeRole?period=$safePeriod",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load leaderboard");
    }

    return jsonDecode(response.body);
  }
}
