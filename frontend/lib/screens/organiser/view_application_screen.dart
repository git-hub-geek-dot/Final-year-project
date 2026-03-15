import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/chat_service.dart';
import '../../services/token_service.dart';
import '../../utils/application_status.dart';
import '../../utils/ist_date_time.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../chat/chat_screen.dart';
import '../rating/rating_screen.dart';

class ViewApplicationScreen extends StatefulWidget {
  final int applicationId;
  final bool slotsFull;
  final int approvedCount;
  final int volunteersRequired;

  const ViewApplicationScreen({
    super.key,
    required this.applicationId,
    this.slotsFull = false,
    this.approvedCount = 0,
    this.volunteersRequired = 0,
  });

  @override
  State<ViewApplicationScreen> createState() => _ViewApplicationScreenState();
}

class _ViewApplicationScreenState extends State<ViewApplicationScreen> {
  bool loading = true;
  bool actionLoading = false;
  String? errorMessage;
  late int approvedCount;
  late int volunteersRequired;

  Map<String, dynamic>? application;

  @override
  void initState() {
    super.initState();
    approvedCount = widget.approvedCount;
    volunteersRequired = widget.volunteersRequired;
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
    final wantsApprove = status.toLowerCase() == "approved";
    if (wantsApprove && _isApproveBlockedByCapacity()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_slotsFullMessage)),
      );
      return;
    }

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
            content: Text(
              "Application marked as ${statusLabel(status).toLowerCase()}.",
            ),
          ),
        );

        setState(() {
          application?["status"] = status;
        });

        Navigator.pop(context, true);
      } else {
        final responseData = _decodeMap(response.body);
        final backendApprovedCount = _asInt(responseData?["approved_count"]);
        final backendVolunteersRequired =
            _asInt(responseData?["volunteers_required"]);

        if (backendVolunteersRequired > 0) {
          setState(() {
            approvedCount = backendApprovedCount;
            volunteersRequired = backendVolunteersRequired;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_responseErrorMessage(response.body))),
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
    return applicationStatusColor(status);
  }

  String statusLabel(String status) {
    return applicationStatusLabel(status);
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _responseErrorMessage(String rawBody) {
    final decoded = _decodeMap(rawBody);
    final error = decoded?["error"]?.toString();
    final message = decoded?["message"]?.toString();
    if (error != null && error.isNotEmpty) return error;
    if (message != null && message.isNotEmpty) return message;
    return "Failed to update application status.";
  }

  bool _isApprovedStatus(String status) {
    return isApprovedApplicationStatus(status);
  }

  bool _isReviewActionable(String status) {
    return isActionableReviewStatus(status);
  }

  String _finalStatusMessage(String status) {
    switch (normalizeApplicationStatus(status)) {
      case "approved":
        return "This application is already approved.";
      case "rejected":
        return "This application is already rejected.";
      case "cancelled":
        return "This application has been cancelled.";
      case "completed":
        return "This participation is already completed.";
      case "no_show":
        return "This volunteer was marked as no-show.";
      default:
        return "This application can no longer be changed.";
    }
  }

  bool _isApproveBlockedByCapacity() {
    final currentStatus = normalizeApplicationStatus(application?["status"]);
    if (_isApprovedStatus(currentStatus)) return false;
    if (volunteersRequired > 0) {
      return approvedCount >= volunteersRequired;
    }
    return widget.slotsFull;
  }

  String get _slotsFullMessage {
    if (volunteersRequired > 0) {
      return "Cannot approve. Slots are full ($approvedCount/$volunteersRequired).";
    }
    return "Cannot approve. Slots are full.";
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == "true" || text == "1" || text == "t" || text == "yes";
  }

  String _normalizedAttendanceStatus(dynamic value) {
    final text = (value ?? "").toString().trim().toLowerCase();
    if (text == "present" || text == "absent") return text;
    return "unmarked";
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return IstDateTime.tryParse(value);
  }

  DateTime _dateWithTime(DateTime date, dynamic rawTime) {
    final text = rawTime?.toString() ?? "";
    if (text.isEmpty) {
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    final parts = text.split(":");
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  bool _isEventCompleted(Map<String, dynamic>? app) {
    if (app == null) return false;

    if (_asBool(app["event_completed"])) return true;

    final status = (app["event_status"] ?? "").toString().toLowerCase();
    if (status == "completed") return true;
    if (status == "draft" || status == "deleted") return false;

    final eventDate = _parseDate(app["event_date"]);
    if (eventDate == null) return false;
    final endDate = _parseDate(app["end_date"]) ?? eventDate;
    final endDateTime = _dateWithTime(endDate, app["end_time"]);
    return IstDateTime.now().isAfter(endDateTime);
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
    final normalizedStatus = normalizeApplicationStatus(status);
    final canReviewApplication = _isReviewActionable(normalizedStatus);
    final approveBlockedByCapacity =
        canReviewApplication && _isApproveBlockedByCapacity();
    final attendanceStatus =
        _normalizedAttendanceStatus(app?["attendance_status"]);
    final showRatingAction =
        normalizedStatus == "approved" || normalizedStatus == "completed";
    final canRateVolunteer = showRatingAction &&
        _isEventCompleted(app) &&
        attendanceStatus != "absent";

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
                        if (attendanceStatus != "unmarked")
                          infoRow(
                            "Attendance",
                            attendanceStatus == "present"
                                ? "Present"
                                : "Absent",
                            compact: compact,
                          ),
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
                              if (showRatingAction) ...[
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
                                    onPressed:
                                        canRateVolunteer ? openRating : null,
                                    icon: const Icon(Icons.star_border),
                                    label: Text(
                                      canRateVolunteer
                                          ? "Rate Volunteer"
                                          : attendanceStatus == "absent"
                                              ? "Absent volunteer"
                                              : "Rate After Completion",
                                      style: TextStyle(
                                          fontSize: compact ? 16 : 18),
                                    ),
                                  ),
                                ),
                                if (!canRateVolunteer) ...[
                                  SizedBox(height: compact ? 6 : 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "Rating unlocks after event completion.",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: compact ? 12 : 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                              if (approveBlockedByCapacity) ...[
                                SizedBox(height: compact ? 8 : 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4F4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Color(0xFFB91C1C),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _slotsFullMessage,
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (canReviewApplication) ...[
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
                                          onPressed: actionLoading ||
                                                  approveBlockedByCapacity
                                              ? null
                                              : () => updateStatus("approved"),
                                          child: Text(
                                            actionLoading
                                                ? "Please wait..."
                                                : approveBlockedByCapacity
                                                    ? "Slots Full"
                                                    : "Approve",
                                            style: TextStyle(
                                                fontSize: compact ? 16 : 18),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                SizedBox(height: compact ? 8 : 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    _finalStatusMessage(normalizedStatus),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
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
