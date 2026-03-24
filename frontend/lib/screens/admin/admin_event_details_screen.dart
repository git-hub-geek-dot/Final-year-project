import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import '../../services/admin_service.dart';
import '../../utils/ist_date_time.dart';
import 'admin_applications_screen.dart';
import '../../widgets/robust_image.dart';

class AdminEventDetailsScreen extends StatefulWidget {
  final Map event;

  const AdminEventDetailsScreen({super.key, required this.event});

  @override
  State<AdminEventDetailsScreen> createState() =>
      _AdminEventDetailsScreenState();
}

class _AdminEventDetailsScreenState extends State<AdminEventDetailsScreen> {
  bool loadingStats = true;
  int applied = 0;
  int approved = 0;
  int pending = 0;
  int waitlisted = 0;
  int rejected = 0;
  int cancelled = 0;
  int completed = 0;
  String? statsError;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    final eventId = _toInt(widget.event["id"]);
    if (eventId == null) {
      if (mounted) {
        setState(() {
          loadingStats = false;
          statsError = "Invalid event ID";
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          loadingStats = true;
          statsError = null;
        });
      }

      final data = await AdminService.getAllApplications(
        page: 1,
        limit: 1,
        eventId: eventId,
      );
      final summary = data["summary"] is Map
          ? Map<String, dynamic>.from(data["summary"] as Map)
          : <String, dynamic>{};

      if (mounted) {
        setState(() {
          applied = _toInt(summary["applied"]) ?? 0;
          approved = _toInt(summary["approved"]) ?? 0;
          pending = _toInt(summary["pending"]) ?? 0;
          waitlisted = _toInt(summary["waitlisted"]) ?? 0;
          rejected = _toInt(summary["rejected"]) ?? 0;
          cancelled = _toInt(summary["cancelled"]) ?? 0;
          completed = _toInt(summary["completed"]) ?? 0;
          loadingStats = false;
          statsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingStats = false;
          statsError = e.toString().replaceFirst("Exception: ", "");
        });
      }
    }
  }

  Future<void> _showNotifyEventDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Notify event users"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: "Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          messageController.text.trim().isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Please fill in all fields"),
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      final rawId = widget.event["id"];
                      final eventId = rawId is int
                          ? rawId
                          : int.tryParse(rawId?.toString() ?? "");
                      if (eventId == null) {
                        if (dialogContext.mounted) {
                          setState(() => isLoading = false);
                        }
                        messenger.showSnackBar(
                          const SnackBar(content: Text("Invalid event id")),
                        );
                        return;
                      }

                      try {
                        await AdminService.sendEventNotification(
                          eventId: eventId,
                          title: titleController.text.trim(),
                          message: messageController.text.trim(),
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Notification sent"),
                          ),
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() => isLoading = false);
                        }
                        messenger.showSnackBar(
                          SnackBar(content: Text("Send failed: $e")),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Send"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final eventId = _toInt(event["id"]);
    final bannerUrl = event["banner_url"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Details"),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: _showNotifyEventDialog,
          ),
        ],
      ),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Banner
                bannerUrl != null && bannerUrl.toString().isNotEmpty
                    ? RobustImage(
                        url: bannerUrl.toString(),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No banner',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Title
                      Text(
                        event["title"] ?? "Untitled Event",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Event Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _eventStatusColor(
                            _normalizedEventStatus(event),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _eventStatusLabel(_normalizedEventStatus(event))
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Application Statistics
                      const Text(
                        "Application Statistics",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (loadingStats)
                        const Center(child: CircularProgressIndicator())
                      else if (statsError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  statsError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                              TextButton(
                                onPressed: loadStats,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = constraints.maxWidth >= 720
                                ? (constraints.maxWidth - 24) / 4
                                : (constraints.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Applied",
                                    applied.toString(),
                                    Icons.people,
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Approved",
                                    approved.toString(),
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Pending",
                                    pending.toString(),
                                    Icons.schedule,
                                    color: Colors.orange,
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Waitlisted",
                                    waitlisted.toString(),
                                    Icons.hourglass_bottom,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Rejected",
                                    rejected.toString(),
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Cancelled",
                                    cancelled.toString(),
                                    Icons.remove_circle_outline,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _StatBox(
                                    "Completed",
                                    completed.toString(),
                                    Icons.task_alt,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                      const SizedBox(height: 24),

                      // Event Details
                      const Text(
                        "Event Information",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _detailRow("Description",
                          event["description"] ?? "No description"),
                      _detailRow(
                          "Location", event["location"] ?? "No location"),
                      _detailRow("Event Date", _formatEventDateRange(event)),
                      _detailRow("Start Time", _eventStartTime(event)),
                      _detailRow("End Time", _eventEndTime(event)),
                      _detailRow(
                        "Max Volunteers",
                        (event["volunteers_required"] ??
                                    event["max_volunteers"])
                                ?.toString() ??
                            "Unlimited",
                      ),
                      _detailRow(
                        "Organiser",
                        event["organiser_name"] ??
                            event["organizer_name"] ??
                            "Unknown",
                      ),
                      _detailRow("Created", _fmtDate(event["created_at"])),

                      const SizedBox(height: 24),

                      // Responsibilities
                      if (event["responsibilities"] != null &&
                          event["responsibilities"].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Responsibilities",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(event["responsibilities"].toString()),
                            const SizedBox(height: 16),
                          ],
                        ),

                      // Requirements
                      if (event["requirements"] != null &&
                          event["requirements"].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Requirements",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(event["requirements"].toString()),
                            const SizedBox(height: 16),
                          ],
                        ),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: eventId == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminApplicationsScreen(
                                            eventId: eventId,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.people),
                              label: const Text("View Applications"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _normalizedEventStatus(Map event) {
    final raw = (event["computed_status"] ?? event["status"] ?? "")
        .toString()
        .toLowerCase();
    if (raw == "closed") return "cancelled";
    if (raw == "deleted" || raw == "deleted_by_admin") {
      return "deleted_by_admin";
    }
    return raw.isEmpty ? "open" : raw;
  }

  String _eventStatusLabel(String status) {
    switch (status) {
      case "upcoming":
        return "Upcoming";
      case "ongoing":
        return "Ongoing";
      case "completed":
        return "Completed";
      case "cancelled":
        return "Cancelled";
      case "deleted_by_admin":
        return "Removed";
      case "draft":
        return "Draft";
      case "open":
      default:
        return "Open";
    }
  }

  Color _eventStatusColor(String status) {
    switch (status) {
      case "upcoming":
        return Colors.blue;
      case "ongoing":
      case "open":
        return Colors.green;
      case "completed":
        return Colors.grey;
      case "cancelled":
        return Colors.red;
      case "deleted_by_admin":
        return Colors.grey;
      case "draft":
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value ?? "-")),
        ],
      ),
    );
  }

  static String _formatEventDateRange(Map event) {
    final startDateRaw = event["event_date"]?.toString();
    final endDateRaw = event["end_date"]?.toString();

    if (startDateRaw == null || startDateRaw.isEmpty) return "-";
    final startDate = IstDateTime.formatDate(startDateRaw);

    // If no end date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startDate;
    }

    final endDate = IstDateTime.formatDate(endDateRaw);

    // If dates are the same, show single date
    if (startDate == endDate) {
      return startDate;
    }

    // Show date range for multi-day events
    return "$startDate to $endDate";
  }

  static String _fmtDate(dynamic value) {
    return IstDateTime.formatDate(value);
  }

  static String _fmtTime(dynamic value) {
    return IstDateTime.formatTime(value);
  }

  static String _eventStartTime(Map event) {
    final direct = _timeOrNull(event["start_time"] ?? event["startTime"]);
    if (direct != null) return direct;

    final fromSchedules =
        _timeFromFirstSchedule(event, "start_time", "startTime");
    return fromSchedules ?? "-";
  }

  static String _eventEndTime(Map event) {
    final direct = _timeOrNull(event["end_time"] ?? event["endTime"]);
    if (direct != null) return direct;

    final fromSchedules = _timeFromFirstSchedule(event, "end_time", "endTime");
    return fromSchedules ?? "-";
  }

  static String? _timeFromFirstSchedule(
    Map event,
    String snakeKey,
    String camelKey,
  ) {
    final schedules = event["daily_schedules"];
    if (schedules is! List || schedules.isEmpty) return null;

    final first = schedules.first;
    if (first is! Map) return null;
    return _timeOrNull(first[snakeKey] ?? first[camelKey]);
  }

  static String? _timeOrNull(dynamic value) {
    final formatted = IstDateTime.formatTime(value);
    if (formatted == "-" || formatted.trim().isEmpty) return null;
    return formatted;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatBox(this.label, this.value, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.1) ?? const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color?.withValues(alpha: 0.3) ?? Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}
