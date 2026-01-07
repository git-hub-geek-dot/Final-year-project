import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../config/api_config.dart';

class AdminService {
  // Fetch all events
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

  // Delete event
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

  // Fetch all users
static Future<List<dynamic>> getAllUsers() async {
  
  final token = await TokenService.getToken();
  if (token == null) {
    throw Exception("Admin token missing");
    
}
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

// Block / Unblock user
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

// Fetch all applications
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

// Cancel application
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


}
