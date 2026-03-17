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
  bool shortlistLoading = false;
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
      default:
        return "This application can no longer be changed.";
    }
  }

  Future<void> updateShortlist(bool shortlisted) async {
    if (shortlistLoading) return;
    try {
      setState(() => shortlistLoading = true);

      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        setState(() => shortlistLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      final url = Uri.parse(
        "${ApiConfig.baseUrl}/applications/${widget.applicationId}/shortlist",
      );

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"shortlisted": shortlisted}),
      );

      setState(() => shortlistLoading = false);

      if (response.statusCode == 200) {
        setState(() {
          application?["is_shortlisted"] = shortlisted;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shortlisted ? "Added to shortlist" : "Removed from shortlist",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_responseErrorMessage(response.body))),
        );
      }
    } catch (e) {
      setState(() => shortlistLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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

  List<String> _asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? "")
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(",")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  String _normalizedAttendanceStatus(dynamic value) {
    final text = (value ?? "").toString().trim().toLowerCase();
    if (text == "present" || text == "absent") return text;
    return "unmarked";
  }

  String _normalizedAvailabilityStatus(dynamic value) {
    final text = (value ?? "").toString().trim().toLowerCase();
    if (text == "partial" || text == "partially_available") return "partial";
    if (text == "unsure" || text == "not_sure") return "unsure";
    return "available";
  }

  String _availabilityLabel(String status) {
    switch (status) {
      case "partial":
        return "Partially available";
      case "unsure":
        return "Not sure";
      case "available":
      default:
        return "Available";
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return IstDateTime.tryParse(value);
  }

  String? _normalizeProfileImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    final normalizedSlashes = url.replaceAll("\\", "/");
    final uploadsIndex = normalizedSlashes.indexOf("/uploads/");
    if (uploadsIndex != -1) {
      return "$origin${normalizedSlashes.substring(uploadsIndex)}";
    }

    if (url.startsWith("/uploads/")) {
      return "$origin$url";
    }

    if (url.startsWith("uploads/")) {
      return "$origin/$url";
    }

    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.hasScheme) {
      if (ApiConfig.useCloud) {
        return url;
      }

      final host = parsed.host;
      final isLocalLike = host == "localhost" ||
          host == "127.0.0.1" ||
          host.startsWith("10.") ||
          host.startsWith("192.168.") ||
          host.startsWith("172.");

      if (isLocalLike && host != baseUri.host) {
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    if (url.contains("localhost") || url.contains("127.0.0.1")) {
      if (parsed != null) {
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    return url;
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

  Color _badgeBaseColor(Map<String, dynamic> badge) {
    final name = (badge["name"] ?? "").toString().toLowerCase();
    final threshold = _asInt(badge["threshold"]);

    if (name.contains("bronze")) return const Color(0xFFCD7F32);
    if (name.contains("silver")) return const Color(0xFFC0C0C0);
    if (name.contains("gold")) return const Color(0xFFFFD700);
    if (name.contains("platinum")) return const Color(0xFFE5E4E2);
    if (name.contains("diamond")) return const Color(0xFF4FC3F7);

    if (threshold >= 50) return const Color(0xFFFFD700);
    if (threshold >= 20) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return "-";
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "${date.year}-$month-$day";
  }

  Widget _tagSection(
    String title,
    List<String> items, {
    required bool compact,
    String? emptyLabel,
  }) {
    final displayItems = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 16,
          ),
        ),
        const SizedBox(height: 6),
        if (displayItems.isEmpty)
          Text(
            emptyLabel ?? "Not provided",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: compact ? 12 : 13,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: displayItems
                .map(
                  (item) => Chip(
                    label: Text(
                      item,
                      style: TextStyle(fontSize: compact ? 12 : 13),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _textSection(
    String title,
    String value, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: compact ? 12 : 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _badgeSection(
    List<Map<String, dynamic>> badges, {
    required bool compact,
    Map<String, dynamic>? topBadge,
  }) {
    final items = badges
        .map((b) => b["name"]?.toString().trim() ?? "")
        .where((name) => name.isNotEmpty)
        .toList();
    final topBadgeName = topBadge?["name"]?.toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Badges",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 16,
          ),
        ),
        if (topBadgeName != null && topBadgeName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            "Top badge: $topBadgeName",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            "No badges yet",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: compact ? 12 : 13,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: badges.map((badge) {
              final name = (badge["name"] ?? "Badge").toString();
              final baseColor = _badgeBaseColor(badge);
              return Chip(
                label: Text(
                  name,
                  style: TextStyle(fontSize: compact ? 12 : 13),
                ),
                backgroundColor: baseColor.withValues(alpha: 0.18),
                shape: StadiumBorder(
                  side: BorderSide(color: baseColor.withValues(alpha: 0.5)),
                ),
                labelStyle: TextStyle(color: baseColor),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _categorySection(
    List<Map<String, dynamic>> categories, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Past Event Categories",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: categories.map((row) {
            final name = (row["name"] ?? "Category").toString();
            final count = _asInt(row["count"]);
            return Chip(
              label: Text(
                "$name ($count)",
                style: TextStyle(fontSize: compact ? 12 : 13),
              ),
              backgroundColor: const Color(0xFFF1F5F9),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _recentParticipationSection(
    List<Map<String, dynamic>> rows, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recent Participation",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            "No recent participation yet.",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: compact ? 12 : 13,
            ),
          )
        else
          Column(
            children: rows.map((row) {
              final title = (row["title"] ?? "Event").toString();
              final eventDate = _parseDate(row["end_date"]) ??
                  _parseDate(row["event_date"]);
              final statusRaw = row["application_status"];
              final status = normalizeApplicationStatus(statusRaw);
              final attendance = _normalizedAttendanceStatus(
                row["attendance_status"],
              );

              String statusLabelText = applicationStatusLabel(status);
              if (attendance == "absent") {
                statusLabelText = "Absent";
              }

              Color statusColor = applicationStatusColor(status);
              if (attendance == "absent") {
                statusColor = Colors.deepOrange;
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: compact ? 13 : 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Date: ${_formatShortDate(eventDate)}",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: compact ? 12 : 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        statusLabelText.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final compact = screenHeight < 780 || screenWidth < 380;
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
    final profileUrl =
        _normalizeProfileImageUrl(app?["profile_picture_url"]?.toString());
    final isVerified = _asBool(app?["isVerified"]);
    final isShortlisted = _asBool(app?["is_shortlisted"]);
    final priorExperience =
        (app?["prior_experience"] ?? app?["priorExperience"] ?? "")
            .toString()
            .trim();
    final availabilityStatus = _normalizedAvailabilityStatus(
      app?["availability_status"] ?? app?["availabilityStatus"],
    );
    final skills = _asStringList(app?["skills"]);
    final interests = _asStringList(app?["interests"]);
    final badges = _asMapList(app?["badges"]);
    final topBadge = _asMap(app?["top_badge"]);
    final categorySummary = _asMapList(app?["category_summary"]);
    final recentParticipation = _asMapList(app?["recent_participation"]);
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: const Color(0xFFE9E4FF),
                            backgroundImage: profileUrl != null
                                ? NetworkImage(profileUrl)
                                : null,
                            child: profileUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: avatarRadius,
                                    color: Colors.grey.shade600,
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                volunteerName.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                            ],
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: shortlistLoading
                                  ? null
                                  : () => updateShortlist(!isShortlisted),
                              child: Icon(
                                isShortlisted
                                    ? Icons.star
                                    : Icons.star_border,
                                color: isShortlisted
                                    ? const Color(0xFFF59E0B)
                                    : Colors.grey.shade600,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 6 : 8),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
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
                        ),
                        SizedBox(height: sectionGap),
                        infoRow("Email", email.toString(), compact: compact),
                        infoRow("Location", city.toString(), compact: compact),
                        infoRow("Contact", contact.toString(),
                            compact: compact),
                        infoRow(
                          "Availability",
                          _availabilityLabel(availabilityStatus),
                          compact: compact,
                        ),
                        if (attendanceStatus != "unmarked")
                          infoRow(
                            "Attendance",
                            attendanceStatus == "present"
                                ? "Present"
                                : "Absent",
                            compact: compact,
                          ),
                        if (priorExperience.isNotEmpty) ...[
                          SizedBox(height: compact ? 8 : 12),
                          _textSection(
                            "Prior Experience",
                            priorExperience,
                            compact: compact,
                          ),
                        ],
                        if (skills.isNotEmpty || interests.isNotEmpty) ...[
                          SizedBox(height: compact ? 8 : 12),
                          _tagSection(
                            "Skills",
                            skills,
                            compact: compact,
                            emptyLabel: "Not provided",
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          _tagSection(
                            "Interests",
                            interests,
                            compact: compact,
                            emptyLabel: "Not provided",
                          ),
                        ],
                        if (badges.isNotEmpty || topBadge != null) ...[
                          SizedBox(height: compact ? 8 : 12),
                          _badgeSection(
                            badges,
                            topBadge: topBadge,
                            compact: compact,
                          ),
                        ],
                        if (categorySummary.isNotEmpty) ...[
                          SizedBox(height: compact ? 8 : 12),
                          _categorySection(
                            categorySummary,
                            compact: compact,
                          ),
                        ],
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
                        _recentParticipationSection(
                          recentParticipation,
                          compact: compact,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: compact ? 16 : 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
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
