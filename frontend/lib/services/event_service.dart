import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class EventService {
  static const String baseUrl = "http://10.0.2.2:4000/api";


  /// ================= CREATE EVENT =================
  static Future<bool> createEvent({
    required String title,
    required String description,
    required String location,
    required String eventDate,
  }) async {
    final token = await TokenService.getToken();
    print("MY EVENTS TOKEN 👉 $token");

    if (token == null) {
      throw Exception("No token found");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/events"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
        "location": location,
        "event_date": eventDate,
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
      Uri.parse("$baseUrl/events/my-events"),
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
