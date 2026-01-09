import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_service.dart';

class EventService {
  /// ================= CREATE EVENT =================
  static Future<bool> createEvent({
    required String title,
    required String description,
    required String location,

    /// Dates
    required String eventDate, // start date (YYYY-MM-DD)
    required String applicationDeadline,

    /// Volunteers
    required int volunteersRequired,

    /// Paid / Unpaid
    required String eventType, // "paid" | "unpaid"
    double? paymentPerDay,

    /// Optional
    String? bannerUrl,

    /// Categories (list of category IDs)
    required List<int> categories,
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
        "application_deadline": applicationDeadline,
        "volunteers_required": volunteersRequired,
        "event_type": eventType,
        "payment_per_day": eventType == "paid" ? paymentPerDay : null,
        "banner_url": bannerUrl,
        "categories": categories,
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
      throw Exception("Failed to fetch my events");
    }
  }
}
