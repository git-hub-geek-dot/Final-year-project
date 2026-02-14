import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/token_service.dart';
import 'view_event_screen.dart';

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  bool loading = true;
  String? errorMessage;
  List applications = [];

  @override
  void initState() {
    super.initState();
    fetchMyApplications();
  }

  Future<void> fetchMyApplications() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final token = await TokenService.getToken();

      if (token == null || token.isEmpty) {
        setState(() {
          loading = false;
          errorMessage = "Token not found. Please login again.";
        });
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/applications/my");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("STATUS => ${response.statusCode}");
      print("BODY => ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // ✅ handle both formats:
        // 1) {applications: [...]}
        // 2) [...] direct list
        if (decoded is Map && decoded["applications"] is List) {
          applications = decoded["applications"];
        } else if (decoded is List) {
          applications = decoded;
        } else {
          applications = [];
        }

        applications = applications.where((app) {
          final status = app["status"]?.toString().toLowerCase() ?? "";
          if (status == "accepted") return true;
          return !_isPastEventDate(app["event_date"]?.toString());
        }).toList();

        setState(() {
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = "Error ${response.statusCode}: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> openEventDetails(int eventId) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final event = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewEventScreen(event: event),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load event details")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load event details")),
      );
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
        return Colors.green;
      case "rejected":
      case "cancelled":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
      case "approved":
        return "Approved";
      case "rejected":
        return "Rejected";
      case "cancelled":
        return "Cancelled";
      case "pending":
        return "Pending";
      default:
        return status;
    }
  }

  bool _isPastEventDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return false;

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return false;

    final now = DateTime.now();
    final eventDateOnly = DateTime(parsed.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);

    return eventDateOnly.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Applications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMyApplications,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : applications.isEmpty
                  ? const Center(child: Text("No applications found"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final app = applications[index];

                        final title = app["title"] ?? "Unknown Event";
                        final location = app["location"] ?? "";
                        final status = app["status"] ?? "pending";
                        final cancelReason =
                            (app["admin_cancel_reason"] ?? "").toString();
                        final subtitle = status.toString().toLowerCase() ==
                                    "cancelled" &&
                                cancelReason.isNotEmpty
                            ? "$location\nReason: $cancelReason"
                            : location.toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text(subtitle),
                            isThreeLine: status.toString().toLowerCase() ==
                                    "cancelled" &&
                                cancelReason.isNotEmpty,
                            onTap: () async {
                              final raw = app["event_id"];
                              final eventId = raw is int
                                  ? raw
                                  : int.tryParse(raw?.toString() ?? "");
                              if (eventId == null) return;
                              await openEventDetails(eventId);
                            },
                            trailing: Chip(
                              label: Text(
                                statusLabel(status.toString()).toUpperCase(),
                              ),
                              backgroundColor:
                                  statusColor(status).withOpacity(0.15),
                              labelStyle:
                                  TextStyle(color: statusColor(status)),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
