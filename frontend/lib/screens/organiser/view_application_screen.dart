import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../chat/chat_screen.dart';
import '../../services/chat_service.dart';
import '../rating/rating_screen.dart';

class ViewApplicationScreen extends StatefulWidget {
  final int applicationId;

  const ViewApplicationScreen({
    super.key,
    required this.applicationId,
  });

  @override
  State<ViewApplicationScreen> createState() => _ViewApplicationScreenState();
}

class _ViewApplicationScreenState extends State<ViewApplicationScreen> {
  bool loading = true;
  bool actionLoading = false;
  String? errorMessage;

  Map<String, dynamic>? application; // ✅ stores API response

  @override
  void initState() {
    super.initState();
    loadApplicationDetails();
  }

  Future<void> loadApplicationDetails() async {
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

      /// ✅ API to get single application details
      /// You must have backend endpoint like:
      /// GET /applications/:id
      final url =
          Uri.parse("${ApiConfig.baseUrl}/applications/${widget.applicationId}");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // supports both: {application: {...}} OR direct {...}
        final app = (data is Map && data["application"] != null)
            ? data["application"]
            : data;

        setState(() {
          application = Map<String, dynamic>.from(app);
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = "Failed: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> updateStatus(String status) async {
    try {
      setState(() => actionLoading = true);

      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        setState(() => actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      /// ✅ API to update application status
      /// Example backend endpoint:
      /// PUT /applications/:id/status   body: {status:"accepted"|"rejected"}
      final url = Uri.parse(
          "${ApiConfig.baseUrl}/applications/${widget.applicationId}/status");

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"status": status}),
      );

      setState(() => actionLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Application ${statusLabel(status).toUpperCase()} ✅",
            ),
          ),
        );

        // ✅ update locally
        setState(() {
          application?["status"] = status;
        });

        // ✅ go back and refresh list
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (e) {
      setState(() => actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> openChat() async {
    final app = application;
    if (app == null) return;

    final eventId = app["event_id"];
    final volunteerId = app["volunteer_id"];
    if (eventId == null || volunteerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat info not available")),
      );
      return;
    }

    try {
      final thread = await ChatService.getOrCreateThread(
        eventId: eventId,
        volunteerId: volunteerId,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            threadId: thread["id"],
            title: "Chat",
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to open chat")),
      );
    }
  }

  void openRating() {
    final app = application;
    if (app == null) return;
    final volunteerId = app["volunteer_id"];
    final eventId = app["event_id"];
    if (volunteerId == null || eventId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          eventId: eventId,
          rateeId: volunteerId,
          title: "Rate Volunteer",
        ),
      ),
    );
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
        return Colors.green;
      case "rejected":
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
      case "pending":
        return "Pending";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = application;

    final volunteerName = app?["name"] ?? app?["volunteer_name"] ?? "Volunteer";
    final email = app?["email"] ?? app?["volunteer_email"] ?? "-";
    final city = app?["city"] ?? "-";
    final contact = app?["contact_number"]?.toString() ??
        app?["contact"]?.toString() ??
        "-";
    final status = app?["status"]?.toString() ?? "pending";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Volunteer Details"),
        actions: [
          IconButton(
            onPressed: loadApplicationDetails,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? RefreshIndicator(
                  onRefresh: loadApplicationDetails,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadApplicationDetails,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                      const CircleAvatar(radius: 40),
                      const SizedBox(height: 12),

                      Text(
                        volunteerName.toString(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          statusLabel(status.toString()).toUpperCase(),
                        ),
                        backgroundColor:
                            statusColor(status).withOpacity(0.15),
                        labelStyle: TextStyle(color: statusColor(status)),
                      ),

                      const SizedBox(height: 16),

                      infoRow("Email", email.toString()),
                      infoRow("Location", city.toString()),
                      infoRow("Contact", contact.toString()),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            StatItem("—", "Events"),
                            StatItem("—", "Rating"),
                            StatItem("—", "Completion"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: openChat,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Message Volunteer"),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (status == "accepted")
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: openRating,
                            icon: const Icon(Icons.star_border),
                            label: const Text("Rate Volunteer"),
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: actionLoading
                                  ? null
                                  : () => updateStatus("rejected"),
                              child: Text(
                                actionLoading ? "Please wait..." : "Reject",
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: actionLoading
                                  ? null
                                  : () => updateStatus("accepted"),
                              child: Text(
                                actionLoading ? "Please wait..." : "Approve",
                              ),
                            ),
                          ),
                        ],
                        )
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: const OrganiserBottomNav(
        currentIndex: 0,
        isRootScreen: false,
      ),
    );
  }
}

Widget infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Flexible(
          child: Text(
            demonstrateShortValue(value),
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

String demonstrateShortValue(String v) {
  if (v.length > 32) return "${v.substring(0, 32)}...";
  return v;
}

class StatItem extends StatelessWidget {
  final String value;
  final String label;

  const StatItem(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
