import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import '../../utils/application_status.dart';
import '../../utils/ist_date_time.dart';
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
      "pending"; // pending | approved | waitlisted | rejected | cancelled | absent | completed
  String selectedSort = "newest"; // newest | oldest | name
  String selectedAvailability = "all"; // all | available | partial | unsure
  String selectedShortlist = "all"; // all | shortlisted | not_shortlisted
  bool loading = true;
  String? loadError;
  List applications = [];
  int volunteersRequired = 0;
  int approvedCount = 0;

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
    } catch (e) {
      setState(() {
        loading = false;
        loadError = "Failed to load applications. Please try again.";
      });
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
      final statusMatches = selectedStatus == "absent"
          ? _normalizedAttendanceStatus(a) == "absent"
          : _normalizedStatus(a) == selectedStatus;

      if (!statusMatches) return false;

      if (selectedAvailability != "all") {
        return _normalizedAvailabilityStatus(a) == selectedAvailability;
      }

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
        return "Oldest";
      case "name":
        return "Name A-Z";
      case "newest":
      default:
        return "Newest";
    }
  }

  String get selectedAvailabilityLabel {
    switch (selectedAvailability) {
      case "available":
        return "Available";
      case "partial":
        return "Partially available";
      case "unsure":
        return "Not sure";
      case "all":
      default:
        return "All";
    }
  }

  String get selectedShortlistLabel {
    switch (selectedShortlist) {
      case "shortlisted":
        return "Shortlisted";
      case "not_shortlisted":
        return "Not shortlisted";
      case "all":
      default:
        return "All";
    }
  }

  String get emptyMessage {
    switch (selectedStatus) {
      case "approved":
        return "No approved applications yet";
      case "waitlisted":
        return "No waitlisted applications yet";
      case "rejected":
        return "No rejected applications yet";
      case "cancelled":
        return "No cancelled applications yet";
      case "absent":
        return "No absent volunteers marked yet";
      case "completed":
        return "No completed applications yet";
      case "pending":
      default:
        return "No pending applications yet";
    }
  }

  Map<String, int> get statusCounts {
    var pending = 0;
    var approved = 0;
    var rejected = 0;
    var waitlisted = 0;
    var cancelled = 0;
    var absent = 0;
    var completed = 0;

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
      } else if (_normalizedAttendanceStatus(application) == "absent") {
        absent++;
      } else if (status == "completed") {
        completed++;
      }
    }

    return {
      "pending": pending,
      "approved": approved,
      "waitlisted": waitlisted,
      "rejected": rejected,
      "cancelled": cancelled,
      "absent": absent,
      "completed": completed,
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
                  "Volunteerx",
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
                          "Pending (${counts["pending"]})",
                          selectedStatus == "pending",
                          () {
                            setState(() => selectedStatus = "pending");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "Approved (${counts["approved"]})",
                          selectedStatus == "approved",
                          () {
                            setState(() => selectedStatus = "approved");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "Waitlisted (${counts["waitlisted"]})",
                          selectedStatus == "waitlisted",
                          () {
                            setState(() => selectedStatus = "waitlisted");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "Rejected (${counts["rejected"]})",
                          selectedStatus == "rejected",
                          () {
                            setState(() => selectedStatus = "rejected");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "Cancelled (${counts["cancelled"]})",
                          selectedStatus == "cancelled",
                          () {
                            setState(() => selectedStatus = "cancelled");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "Absent (${counts["absent"]})",
                          selectedStatus == "absent",
                          () {
                            setState(() => selectedStatus = "absent");
                          },
                        ),
                        const SizedBox(width: 10),
                        toggleButton(
                          "Completed (${counts["completed"]})",
                          selectedStatus == "completed",
                          () {
                            setState(() => selectedStatus = "completed");
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
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: "newest",
                      child: Text("Newest"),
                    ),
                    PopupMenuItem(
                      value: "oldest",
                      child: Text("Oldest"),
                    ),
                    PopupMenuItem(
                      value: "name",
                      child: Text("Name A-Z"),
                    ),
                  ],
                  child: Row(
                    children: [
                      Text("Sort: $selectedSortLabel"),
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
                const Text(
                  "Availability:",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: selectedAvailability,
                  onSelected: (value) => setState(() {
                    selectedAvailability = value;
                  }),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: "all",
                      child: Text("All"),
                    ),
                    PopupMenuItem(
                      value: "available",
                      child: Text("Available"),
                    ),
                    PopupMenuItem(
                      value: "partial",
                      child: Text("Partially available"),
                    ),
                    PopupMenuItem(
                      value: "unsure",
                      child: Text("Not sure"),
                    ),
                  ],
                  child: Row(
                    children: [
                      Text(selectedAvailabilityLabel),
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
                const Text(
                  "Shortlist:",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: selectedShortlist,
                  onSelected: (value) => setState(() {
                    selectedShortlist = value;
                  }),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: "all",
                      child: Text("All"),
                    ),
                    PopupMenuItem(
                      value: "shortlisted",
                      child: Text("Shortlisted"),
                    ),
                    PopupMenuItem(
                      value: "not_shortlisted",
                      child: Text("Not shortlisted"),
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
                              child: const Text("Retry"),
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
                              return ApplicationCard(
                                name: a["name"] ?? "Unknown",
                                location: a["city"] ?? "-",
                                status: _normalizedStatus(a),
                                attendanceStatus: _normalizedAttendanceStatus(a),
                                availabilityStatus:
                                    _normalizedAvailabilityStatus(a),
                                isShortlisted: _asBool(a["is_shortlisted"]),
                                appliedAt: a["applied_at"],
                                applicationId: a["id"],
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
    required this.slotsFull,
    required this.approvedCount,
    required this.volunteersRequired,
    required this.onRefresh,
  });

  String get statusLabel {
    if (attendanceStatus == "absent") {
      return "ABSENT";
    }
    return applicationStatusLabel(status).toUpperCase();
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
        return "PARTIAL";
      case "unsure":
        return "NOT SURE";
      case "available":
      default:
        return "AVAILABLE";
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
          const CircleAvatar(radius: 24),
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
                const Text(
                  "Volunteer",
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
                        color: statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        statusLabel,
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
                        color: availabilityColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: availabilityColor.withOpacity(0.45),
                        ),
                      ),
                      child: Text(
                        availabilityLabel,
                        style: TextStyle(
                          color: availabilityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      appliedDateText,
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
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          "Slots full ($approvedCount/$volunteersRequired)",
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
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
                                ? "Added to shortlist"
                                : "Removed from shortlist",
                          ),
                        ),
                      );
                    }
                    onRefresh();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Shortlist update failed: $e")),
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
                  text: "View Application",
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
