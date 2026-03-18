import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../localization/localization_extensions.dart';
import '../../services/event_service.dart';
import '../../services/token_service.dart';
import '../../utils/application_status.dart';
import '../../utils/ist_date_time.dart';
import 'package:frontend/config/api_config.dart';
import '../../widgets/organiser_bottom_nav.dart';
import 'view_application_screen.dart';
import '../notifications/notifications_screen.dart';

class ReviewApplicationsScreen extends StatefulWidget {
  final int eventId;

  const ReviewApplicationsScreen({super.key, required this.eventId});

  @override
  State<ReviewApplicationsScreen> createState() =>
      _ReviewApplicationsScreenState();
}

class _ReviewApplicationsScreenState extends State<ReviewApplicationsScreen> {
  String selectedStatus =
      "pending"; // all | pending | approved | waitlisted | rejected | cancelled
  String selectedSort = "newest"; // newest | oldest | name
  String selectedShortlist = "all"; // all | shortlisted | not_shortlisted
  bool loading = true;
  String? loadError;
  List applications = [];
  int volunteersRequired = 0;
  int approvedCount = 0;
  final Map<int, String> _profilePictureUrlByApplicationId = {};

  bool get isSlotsFull =>
      volunteersRequired > 0 && approvedCount >= volunteersRequired;

  @override
  void initState() {
    super.initState();
    loadApplications();
  }

  Future<void> loadApplications() async {
    setState(() {
      loading = true;
      loadError = null;
      _profilePictureUrlByApplicationId.clear();
    });

    try {
      final data = await EventService.fetchApplications(widget.eventId);
      final events = await EventService.fetchMyEvents();
      final event = events.cast<Map>().firstWhere(
            (e) => _asInt(e["id"]) == widget.eventId,
            orElse: () => {},
          );
      final requiredFromEvent = _asInt(event["volunteers_required"]);
      final approvedFromEvent = _asInt(event["approved_count"]);
      final approvedFromApplications = _approvedFromApplications(data);

      setState(() {
        applications = data;
        volunteersRequired = requiredFromEvent;
        approvedCount = approvedFromEvent > 0
            ? approvedFromEvent
            : approvedFromApplications;
        loading = false;
        loadError = null;
      });

      _hydrateMissingProfilePictures(data);
    } catch (e) {
      setState(() {
        loading = false;
        loadError = context.tr("Failed to load applications. Please try again.");
      });
    }
  }

  Future<void> _hydrateMissingProfilePictures(List<dynamic> rows) async {
    final missingIds = <int>[];

    for (final row in rows) {
      if (row is! Map) continue;
      final applicationId = _asInt(row["id"]);
      if (applicationId <= 0) continue;

      final existingUrl = row["profile_picture_url"]?.toString().trim();
      if (existingUrl != null && existingUrl.isNotEmpty) continue;
      if (_profilePictureUrlByApplicationId.containsKey(applicationId)) continue;

      missingIds.add(applicationId);
    }

    if (missingIds.isEmpty) return;

    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) return;

    // Fallback: some deployments don't include profile_picture_url in the list
    // endpoint, but it is present in the single-application details response.
    for (final applicationId in missingIds) {
      if (!mounted) return;

      try {
        final url =
            Uri.parse("${ApiConfig.baseUrl}/applications/$applicationId");
        final response = await http.get(
          url,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );

        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);
        final dynamic app = (decoded is Map && decoded["application"] != null)
            ? decoded["application"]
            : decoded;
        if (app is! Map) continue;

        final pictureUrl = app["profile_picture_url"]?.toString().trim();
        if (pictureUrl == null || pictureUrl.isEmpty) continue;

        if (!mounted) return;
        setState(() {
          _profilePictureUrlByApplicationId[applicationId] = pictureUrl;
        });
      } catch (_) {
        // ignore
      }
    }
  }

  String _normalizedStatus(Map application) {
    return normalizeApplicationStatus(application["status"]);
  }

  String _normalizedAttendanceStatus(Map application) {
    final status =
        (application["attendance_status"] ?? "").toString().trim().toLowerCase();
    if (status == "present" || status == "absent") return status;
    return "unmarked";
  }

  String _normalizedAvailabilityStatus(Map application) {
    final status = (application["availability_status"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    if (status == "partial" || status == "partially_available") return "partial";
    if (status == "unsure" || status == "not_sure") return "unsure";
    return "available";
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return false;
    return value.toString().toLowerCase() == "true";
  }

  List get filtered {
    return applications.where((a) {
      final statusMatches =
          selectedStatus == "all" || _normalizedStatus(a) == selectedStatus;

      if (!statusMatches) return false;

      final isShortlisted = _asBool(a["is_shortlisted"]);
      if (selectedShortlist == "shortlisted" && !isShortlisted) {
        return false;
      }
      if (selectedShortlist == "not_shortlisted" && isShortlisted) {
        return false;
      }

      return true;
    }).toList();
  }

  DateTime _appliedAt(Map application) {
    final raw = application["applied_at"];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return IstDateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _approvedFromApplications(List list) {
    var count = 0;
    for (final item in list) {
      if (item is Map && _normalizedStatus(item) == "approved") {
        count++;
      }
    }
    return count;
  }

  List get visibleApplications {
    final items = [...filtered];
    switch (selectedSort) {
      case "oldest":
        items.sort((a, b) => _appliedAt(a).compareTo(_appliedAt(b)));
        break;
      case "name":
        items.sort((a, b) => (a["name"] ?? "")
            .toString()
            .toLowerCase()
            .compareTo((b["name"] ?? "").toString().toLowerCase()));
        break;
      case "newest":
      default:
        items.sort((a, b) => _appliedAt(b).compareTo(_appliedAt(a)));
        break;
    }
    return items;
  }

  String get selectedSortLabel {
    switch (selectedSort) {
      case "oldest":
        return context.tr("Oldest");
      case "name":
        return context.tr("Name A-Z");
      case "newest":
      default:
        return context.tr("Newest");
    }
  }

  String get selectedShortlistLabel {
    switch (selectedShortlist) {
      case "shortlisted":
        return context.tr("Shortlisted");
      case "not_shortlisted":
        return context.tr("Not shortlisted");
      case "all":
      default:
        return context.tr("All");
    }
  }

  String get emptyMessage {
    switch (selectedStatus) {
      case "all":
        return context.tr("No applications yet");
      case "approved":
        return context.tr("No approved applications yet");
      case "waitlisted":
        return context.tr("No waitlisted applications yet");
      case "rejected":
        return context.tr("No rejected applications yet");
      case "cancelled":
        return context.tr("No cancelled applications yet");
      case "pending":
      default:
        return context.tr("No pending applications yet");
    }
  }

  Map<String, int> get statusCounts {
    final all = applications.length;
    var pending = 0;
    var approved = 0;
    var rejected = 0;
    var waitlisted = 0;
    var cancelled = 0;

    for (final application in applications) {
      final status = _normalizedStatus(application);
      if (status == "pending") {
        pending++;
      } else if (status == "approved") {
        approved++;
      } else if (status == "waitlisted") {
        waitlisted++;
      } else if (status == "rejected") {
        rejected++;
      } else if (status == "cancelled") {
        cancelled++;
      }
    }

    return {
      "all": all,
      "pending": pending,
      "approved": approved,
      "waitlisted": waitlisted,
      "rejected": rejected,
      "cancelled": cancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final counts = statusCounts;

    return Scaffold(
      body: Column(
        children: [
          // 🔷 Header
          Container(
            height: 160,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "VolunteerX",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🔘 Pending / Approved / Rejected Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                     child: Row(
                       children: [
                         toggleButton(
                           "${context.tr("All")} (${counts["all"]})",
                           selectedStatus == "all",
                           () {
                             setState(() => selectedStatus = "all");
                           },
                         ),
                         const SizedBox(width: 10),
                        toggleButton(
                          "${context.tr("Pending")} (${counts["pending"]})",
                           selectedStatus == "pending",
                           () {
                            setState(() => selectedStatus = "pending");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "${context.tr("Approved")} (${counts["approved"]})",
                          selectedStatus == "approved",
                          () {
                            setState(() => selectedStatus = "approved");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "${context.tr("Waitlisted")} (${counts["waitlisted"]})",
                          selectedStatus == "waitlisted",
                          () {
                            setState(() => selectedStatus = "waitlisted");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "${context.tr("Rejected")} (${counts["rejected"]})",
                          selectedStatus == "rejected",
                          () {
                            setState(() => selectedStatus = "rejected");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "${context.tr("Cancelled")} (${counts["cancelled"]})",
                          selectedStatus == "cancelled",
                          () {
                            setState(() => selectedStatus = "cancelled");
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: selectedSort,
                  onSelected: (value) => setState(() => selectedSort = value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "newest",
                      child: Text(context.tr("Newest")),
                    ),
                    PopupMenuItem(
                      value: "oldest",
                      child: Text(context.tr("Oldest")),
                    ),
                    PopupMenuItem(
                      value: "name",
                      child: Text(context.tr("Name A-Z")),
                    ),
                  ],
                  child: Row(
                    children: [
                      Text(
                        context.tr(
                          "Sort: {label}",
                          args: {"label": selectedSortLabel},
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  context.tr("Shortlist:"),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: selectedShortlist,
                  onSelected: (value) => setState(() {
                    selectedShortlist = value;
                  }),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "all",
                      child: Text(context.tr("All")),
                    ),
                    PopupMenuItem(
                      value: "shortlisted",
                      child: Text(context.tr("Shortlisted")),
                    ),
                    PopupMenuItem(
                      value: "not_shortlisted",
                      child: Text(context.tr("Not shortlisted")),
                    ),
                  ],
                  child: Row(
                    children: [
                      Text(selectedShortlistLabel),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 📋 Applications List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loadError!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: loadApplications,
                              child: Text(context.tr("Retry")),
                            ),
                          ],
                        ),
                      )
                    : visibleApplications.isEmpty
                        ? Center(child: Text(emptyMessage))
                         : ListView.builder(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             itemCount: visibleApplications.length,
                              itemBuilder: (context, i) {
                                final a = visibleApplications[i];
                                final applicationId = _asInt(a["id"]);
                                final listProfileUrl =
                                    a["profile_picture_url"]?.toString();
                                final hydratedProfileUrl =
                                    _profilePictureUrlByApplicationId[applicationId];
                                final status = _normalizedStatus(a);

                                String? cancellationInfo;
                                if (status == "cancelled" &&
                                    a.containsKey("volunteer_cancelled_at")) {
                                  final dynamic cancelledAt =
                                      a["volunteer_cancelled_at"];
                                  final bool cancelledByVolunteer =
                                      cancelledAt != null &&
                                          cancelledAt.toString().trim().isNotEmpty;
                                  cancellationInfo = cancelledByVolunteer
                                      ? context.tr("Cancelled by volunteer")
                                      : context.tr("Cancelled by organiser/admin");
                                }
                                return ApplicationCard(
                                  name: a["name"] ?? context.tr("Unknown"),
                                  location: a["city"] ?? "-",
                                  status: status,
                                  attendanceStatus: _normalizedAttendanceStatus(a),
                                  availabilityStatus:
                                      _normalizedAvailabilityStatus(a),
                                  isShortlisted: _asBool(a["is_shortlisted"]),
                                  appliedAt: a["applied_at"],
                                  applicationId: applicationId,
                                   profilePictureUrl:
                                      (listProfileUrl == null ||
                                              listProfileUrl.trim().isEmpty)
                                          ? hydratedProfileUrl
                                          : listProfileUrl,
                                  cancellationInfo: cancellationInfo,
                                  slotsFull: isSlotsFull,
                                  approvedCount: approvedCount,
                                  volunteersRequired: volunteersRequired,
                                  onRefresh: loadApplications,
                                );
                              },
                           ),
          ),
        ],
      ),
      bottomNavigationBar: const OrganiserBottomNav(
        currentIndex: 0,
        isRootScreen: false,
      ),
    );
  }
}

/// 🔘 Toggle Button
Widget toggleButton(String text, bool active, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.white : Colors.black54,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

/// 📄 Application Card
class ApplicationCard extends StatelessWidget {
  final String name;
  final String location;
  final String status;
  final String attendanceStatus;
  final String availabilityStatus;
  final bool isShortlisted;
  final dynamic appliedAt;
  final int applicationId;
  final String? profilePictureUrl;
  final String? cancellationInfo;
  final bool slotsFull;
  final int approvedCount;
  final int volunteersRequired;
  final VoidCallback onRefresh;

  const ApplicationCard({
    super.key,
    required this.name,
    required this.location,
    required this.status,
    required this.attendanceStatus,
    required this.availabilityStatus,
    required this.isShortlisted,
    required this.appliedAt,
    required this.applicationId,
    required this.profilePictureUrl,
    this.cancellationInfo,
    required this.slotsFull,
    required this.approvedCount,
    required this.volunteersRequired,
    required this.onRefresh,
  });

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
        final pathWithQuery =
            parsed.hasQuery ? "${parsed.path}?${parsed.query}" : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    return url;
  }

  String get statusLabel {
    if (attendanceStatus == "absent") {
      return "Absent";
    }
    return applicationStatusLabel(status);
  }

  Color get statusColor {
    if (attendanceStatus == "absent") {
      return Colors.deepOrange;
    }
    return applicationStatusColor(status);
  }

  String get availabilityLabel {
    switch (availabilityStatus) {
      case "partial":
        return "Partially available";
      case "unsure":
        return "Not sure";
      case "available":
      default:
        return "Available";
    }
  }

  Color get availabilityColor {
    switch (availabilityStatus) {
      case "partial":
        return Colors.orange;
      case "unsure":
        return Colors.blueGrey;
      case "available":
      default:
        return Colors.green;
    }
  }

  String get appliedDateText {
    if (appliedAt == null) return "Applied: -";
    final parsed = IstDateTime.tryParse(appliedAt);
    if (parsed == null) return "Applied: -";
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return "Applied: ${parsed.year}-$month-$day";
  }

  @override
  Widget build(BuildContext context) {
    final normalizedProfileUrl = _normalizeProfileImageUrl(profilePictureUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            backgroundImage: normalizedProfileUrl != null
                ? NetworkImage(normalizedProfileUrl)
                : null,
            child: normalizedProfileUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr("Volunteer"),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.85),
                        ),
                      ),
                      child: Text(
                        context.tr(statusLabel).toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: availabilityColor.withValues(alpha: 0.85),
                        ),
                      ),
                      child: Text(
                        context.tr(availabilityLabel).toUpperCase(),
                        style: TextStyle(
                          color: availabilityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      context.tr(
                        "Applied: {date}",
                        args: {"date": appliedDateText.replaceFirst("Applied: ", "")},
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    if (slotsFull && status == "pending")
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Text(
                          context.tr(
                            "Slots full ({approved}/{required})",
                            args: {
                              "approved": approvedCount.toString(),
                              "required": volunteersRequired.toString(),
                            },
                          ),
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (cancellationInfo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    cancellationInfo!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  "📍 $location",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final nextValue = !isShortlisted;
                  try {
                    await EventService.updateShortlistStatus(
                      applicationId: applicationId,
                      shortlisted: nextValue,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            nextValue
                                ? context.tr("Added to shortlist")
                                : context.tr("Removed from shortlist"),
                          ),
                        ),
                      );
                    }
                    onRefresh();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr(
                              "Shortlist update failed: {error}",
                              args: {"error": e.toString()},
                            ),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Icon(
                  isShortlisted ? Icons.star : Icons.star_border,
                  color: isShortlisted ? const Color(0xFFF59E0B) : Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewApplicationScreen(
                        applicationId: applicationId,
                        slotsFull: slotsFull,
                        approvedCount: approvedCount,
                        volunteersRequired: volunteersRequired,
                      ),
                    ),
                  );

                  if (updated == true) {
                    onRefresh(); // 🔄 reload after approve/reject
                  }
                },
                child: actionButton(
                  text: context.tr("View Application"),
                  color: Colors.white,
                  textColor: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🔘 Action Button
Widget actionButton({
  required String text,
  required Color color,
  required Color textColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
