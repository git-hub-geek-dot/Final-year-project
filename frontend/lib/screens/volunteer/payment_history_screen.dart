import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/token_service.dart';

class CompensationStatusScreen extends StatefulWidget {
  const CompensationStatusScreen({super.key});

  @override
  State<CompensationStatusScreen> createState() =>
      _CompensationStatusScreenState();
}

class _CompensationStatusScreenState extends State<CompensationStatusScreen> {
  bool loading = true;
  String? errorMessage;
  List applications = [];

  @override
  void initState() {
    super.initState();
    fetchCompensationStatus();
  }

  Future<void> fetchCompensationStatus() async {
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

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["applications"] is List) {
          applications = decoded["applications"];
        } else if (decoded is List) {
          applications = decoded;
        } else {
          applications = [];
        }

        applications = applications.where((app) {
          final status = (app["status"] ?? "").toString().toLowerCase();
          return status == "accepted" || status == "completed";
        }).toList();

        setState(() => loading = false);
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

  Future<void> _updateStatus(int applicationId, String status) async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final url = Uri.parse(
        "${ApiConfig.baseUrl}/applications/$applicationId/compensation",
      );

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updated = data["application"];
        if (updated != null) {
          setState(() {
            applications = applications.map((app) {
              if (app["id"] == updated["id"]) {
                app["compensation_status"] =
                    updated["compensation_status"];
              }
              return app;
            }).toList();
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status updated")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update status")),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "received":
        return Colors.green;
      case "not_applicable":
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "received":
        return "Received";
      case "not_applicable":
        return "Not applicable";
      default:
        return "Pending";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Compensation Status")),
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
                  ? const Center(
                      child: Text("No approved events yet"),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final app = applications[index];
                        final title = app["title"] ?? "Unknown Event";
                        final location = app["location"] ?? "";
                        final eventType =
                            (app["event_type"] ?? "unpaid").toString();
                        final paymentPerDay = app["payment_per_day"];
                        final status =
                            (app["compensation_status"] ?? "pending")
                                .toString();

                        final isPaid = eventType.toLowerCase() == "paid";
                        final subtitle = isPaid && paymentPerDay != null
                            ? "$location • ₹$paymentPerDay/day"
                            : location;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text(subtitle),
                            trailing: Chip(
                              label: Text(_statusLabel(status)),
                              backgroundColor:
                                  _statusColor(status).withOpacity(0.15),
                              labelStyle:
                                  TextStyle(color: _statusColor(status)),
                            ),
                            onTap: !isPaid
                                ? null
                                : () async {
                                    final choice = await showModalBottomSheet<
                                        String>(
                                      context: context,
                                      builder: (_) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                              ),
                                              title: const Text("Received"),
                                              onTap: () =>
                                                  Navigator.pop(context, "received"),
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.hourglass_top,
                                                color: Colors.orange,
                                              ),
                                              title: const Text("Pending"),
                                              onTap: () =>
                                                  Navigator.pop(context, "pending"),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    if (choice != null) {
                                      final appId = app["id"];
                                      if (appId != null) {
                                        await _updateStatus(appId, choice);
                                      }
                                    }
                                  },
                          ),
                        );
                      },
                    ),
    );
  }
}

