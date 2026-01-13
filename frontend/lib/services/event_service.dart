import 'dart:convert';
import 'dart:io';
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
      // 🌐 Web: send bytes
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          bytes,
          filename: file.name,
        ),
      );
    } else {
      // 📱 Mobile/Desktop: send file path
      request.files.add(
        await http.MultipartFile.fromPath("image", file.path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["url"]; // e.g. http://localhost:4000/uploads/xxx.jpg
    } else {
      throw Exception("Image upload failed: ${response.body}");
    }
  }

  /// ================= CREATE EVENT =================
  static Future<bool> createEvent({
    required String title,
    required String description,
    required String location,
    required String eventDate,
    required String applicationDeadline,
    required int volunteersRequired,
    required String eventType,
    double? paymentPerDay,
    String? bannerUrl,
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
