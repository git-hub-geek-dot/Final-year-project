import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/chat_service.dart';
import '../../services/token_service.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../chat/chat_screen.dart';
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

  Map<String, dynamic>? application;

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

      final url = Uri.parse(
          "${ApiConfig.baseUrl}/applications/${widget.applicationId}");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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

      final url = Uri.parse(
        "${ApiConfig.baseUrl}/applications/${widget.applicationId}/status",
      );

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
            content: Text("Application ${statusLabel(status).toUpperCase()} ✅"),
          ),
        );

        setState(() {
          application?["status"] = status;
        });

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
      case "approved":
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

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final compact = screenHeight < 780;
    final avatarRadius = compact ? 34.0 : 48.0;
    final titleSize = compact ? 24.0 : 34.0;
    final pagePadding = compact ? 10.0 : 16.0;
    final statusVertical = compact ? 6.0 : 8.0;
    final statusHorizontal = compact ? 16.0 : 20.0;
    final sectionGap = compact ? 10.0 : 16.0;
    final statPaddingV = compact ? 10.0 : 16.0;
    final actionButtonHeight = compact ? 44.0 : 52.0;
    final actionContainerPadding = compact ? 8.0 : 12.0;

    final app = application;
    final volunteerName = app?["name"] ?? app?["volunteer_name"] ?? "Volunteer";
    final email = app?["email"] ?? app?["volunteer_email"] ?? "-";
    final city = app?["city"] ?? "-";
    final contact = app?["contact_number"]?.toString() ??
        app?["contact"]?.toString() ??
        "-";
    final status = app?["status"]?.toString() ?? "pending";
    final normalizedStatus = status.toLowerCase();

    final eventsCount = _asInt(
      app?["events_count"] ?? app?["committed_events"] ?? 1,
    );
    final ratingValue = _asDouble(app?["avg_rating"] ?? app?["rating"]);
    final reviewCount = _asInt(app?["review_count"]);
    final completionPercent = _asInt(app?["completion_percent"]);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Volunteer Details"),
        actions: [
          IconButton(
            onPressed: loadApplicationDetails,
            icon: const Icon(Icons.refresh),
          ),
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
                    padding: EdgeInsets.all(pagePadding),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Color(0xFFE9E4FF),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        Text(
                          volunteerName.toString(),
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: compact ? 6 : 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: statusHorizontal,
                            vertical: statusVertical,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor(status).withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            statusLabel(status).toUpperCase(),
                            style: TextStyle(
                              color: statusColor(status),
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 16 : 18,
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        infoRow("Email", email.toString(), compact: compact),
                        infoRow("Location", city.toString(), compact: compact),
                        infoRow("Contact", contact.toString(),
                            compact: compact),
                        SizedBox(height: compact ? 10 : 18),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: statPaddingV,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1D72E8),
                                Color(0xFF03A9F4),
                                Color(0xFF00A651),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              StatItem(
                                "$eventsCount",
                                "Events",
                                compact: compact,
                              ),
                              StatItem(
                                ratingValue.toStringAsFixed(1),
                                reviewCount == 1
                                    ? "1 Review"
                                    : "$reviewCount Reviews",
                                showStar: true,
                                compact: compact,
                              ),
                              StatItem(
                                "$completionPercent%",
                                "Completion",
                                compact: compact,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(actionContainerPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE3E7EF)),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: actionButtonHeight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4C51BF),
                                    side: BorderSide(
                                      color: Colors.grey.shade400,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: openChat,
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: Text(
                                    "Message Volunteer",
                                    style:
                                        TextStyle(fontSize: compact ? 16 : 18),
                                  ),
                                ),
                              ),
                              if (normalizedStatus == "accepted" ||
                                  normalizedStatus == "approved") ...[
                                SizedBox(height: compact ? 8 : 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: actionButtonHeight,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF4C51BF),
                                      side: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: openRating,
                                    icon: const Icon(Icons.star_border),
                                    label: Text(
                                      "Rate Volunteer",
                                      style: TextStyle(
                                          fontSize: compact ? 16 : 18),
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: compact ? 8 : 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: actionButtonHeight,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFEF4444),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: actionLoading
                                            ? null
                                            : () => updateStatus("rejected"),
                                        child: Text(
                                          actionLoading
                                              ? "Please wait..."
                                              : "Reject",
                                          style: TextStyle(
                                              fontSize: compact ? 16 : 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: compact ? 8 : 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: actionButtonHeight,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF16A34A),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: actionLoading
                                            ? null
                                            : () => updateStatus("accepted"),
                                        child: Text(
                                          actionLoading
                                              ? "Please wait..."
                                              : "Approve",
                                          style: TextStyle(
                                              fontSize: compact ? 16 : 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 8),
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

Widget infoRow(String label, String value, {bool compact = false}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: compact ? 16 : 18,
          ),
        ),
        Flexible(
          child: Text(
            demonstrateShortValue(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 16 : 18,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

String demonstrateShortValue(String value) {
  if (value.length > 32) return "${value.substring(0, 32)}...";
  return value;
}

class StatItem extends StatelessWidget {
  final String value;
  final String label;
  final bool showStar;
  final bool compact;

  const StatItem(
    this.value,
    this.label, {
    super.key,
    this.showStar = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showStar)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 16 : 24,
                ),
              ),
              SizedBox(width: compact ? 1 : 2),
              Icon(Icons.star, size: compact ? 11 : 14, color: Colors.white),
            ],
          )
        else
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 16 : 24,
            ),
          ),
        SizedBox(height: compact ? 1 : 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
