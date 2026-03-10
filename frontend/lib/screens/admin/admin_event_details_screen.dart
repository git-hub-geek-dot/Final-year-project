import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import '../../services/admin_service.dart';
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
  int rejected = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<List<dynamic>> _fetchAllApplications() async {
    final allItems = <dynamic>[];
    int currentPage = 1;
    int lastPage = 1;

    do {
      final data = await AdminService.getAllApplications(
        page: currentPage,
        limit: 20,
      );
      final items = (data["items"] as List?) ?? [];
      lastPage = data["totalPages"] ?? currentPage;
      allItems.addAll(items);
      currentPage += 1;
    } while (currentPage <= lastPage);

    return allItems;
  }

  Future<void> loadStats() async {
    try {
      if (mounted) {
        setState(() {
          loadingStats = true;
        });
      }

      final list = await _fetchAllApplications();
      final eventId = _toInt(widget.event["id"]);
      final eventApplications = eventId == null
          ? <dynamic>[]
          : list.where((app) => _toInt(app["event_id"]) == eventId).toList();

      int a = eventApplications.length;
      int ap = 0, p = 0, r = 0;

      for (final x in eventApplications) {
        final s = (x["status"] ?? "pending").toString().toLowerCase();

        if (s == "accepted" || s == "approved") {
          ap++;
        } else if (s == "rejected") {
          r++;
        } else {
          p++;
        }
      }

      if (mounted) {
        setState(() {
          applied = a;
          approved = ap;
          pending = p;
          rejected = r;
          loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loadingStats = false;
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
                          color: _getStatusColor(event["status"]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (event["status"] ?? "active")
                              .toString()
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
                      else
                        Row(
                          children: [
                            _StatBox(
                                "Applied", applied.toString(), Icons.people),
                            _StatBox("Approved", approved.toString(),
                                Icons.check_circle,
                                color: Colors.green),
                            _StatBox(
                                "Pending", pending.toString(), Icons.schedule,
                                color: Colors.orange),
                            _StatBox(
                                "Rejected", rejected.toString(), Icons.cancel,
                                color: Colors.red),
                          ],
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
                      _detailRow("Start Time", _fmtTime(event["start_time"])),
                      _detailRow("End Time", _fmtTime(event["end_time"])),
                      _detailRow(
                        "Max Volunteers",
                        (event["volunteers_required"] ?? event["max_volunteers"])
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminApplicationsScreen(
                                        eventId: widget.event["id"]),
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

  Color _getStatusColor(dynamic status) {
    final s = status?.toString().toLowerCase() ?? "active";
    switch (s) {
      case "active":
      case "open":
        return Colors.green;
      case "completed":
        return Colors.blue;
      case "cancelled":
        return Colors.red;
      case "deleted":
        return Colors.grey;
      default:
        return Colors.orange;
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
    
    final startDate = startDateRaw.split("T")[0];
    
    // If no end date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startDate;
    }
    
    final endDate = endDateRaw.split("T")[0];
    
    // If dates are the same, show single date
    if (startDate == endDate) {
      return startDate;
    }
    
    // Show date range for multi-day events
    return "$startDate to $endDate";
  }

  static String _fmtDate(dynamic value) {
    if (value == null) return "-";
    final text = value.toString();
    if (text.isEmpty) return "-";
    return text.split("T")[0];
  }

  static String _fmtTime(dynamic value) {
    if (value == null) return "-";
    final text = value.toString();
    if (text.isEmpty) return "-";

    // Handle datetime format (e.g., "2024-01-01T14:30:00.000Z")
    final parts = text.split("T");
    if (parts.length > 1) {
      return parts[1].split(".")[0];
    }

    // If no "T" separator, return the time as-is (assuming it's already in time format)
    return text;
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
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
      ),
    );
  }
}
