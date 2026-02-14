import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import '../../widgets/organiser_bottom_nav.dart';
import 'view_application_screen.dart';

class ReviewApplicationsScreen extends StatefulWidget {
  final int eventId;

  const ReviewApplicationsScreen({super.key, required this.eventId});

  @override
  State<ReviewApplicationsScreen> createState() =>
      _ReviewApplicationsScreenState();
}

class _ReviewApplicationsScreenState extends State<ReviewApplicationsScreen> {
  String selectedStatus = "pending"; // pending | approved | rejected
  String selectedSort = "newest"; // newest | oldest | name
  bool loading = true;
  String? loadError;
  List applications = [];

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
      setState(() {
        applications = data;
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
    final status =
        (application["status"] ?? "pending").toString().toLowerCase();
    if (status == "accepted" || status == "approved") return "approved";
    if (status == "rejected") return "rejected";
    return "pending";
  }

  List get filtered {
    return applications
        .where((a) => _normalizedStatus(a) == selectedStatus)
        .toList();
  }

  DateTime _appliedAt(Map application) {
    final raw = application["applied_at"];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
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

  String get emptyMessage {
    switch (selectedStatus) {
      case "approved":
        return "No approved applications yet";
      case "rejected":
        return "No rejected applications yet";
      case "pending":
      default:
        return "No pending applications yet";
    }
  }

  Map<String, int> get statusCounts {
    var pending = 0;
    var approved = 0;
    var rejected = 0;

    for (final application in applications) {
      final status = _normalizedStatus(application);
      if (status == "pending") {
        pending++;
      } else if (status == "approved") {
        approved++;
      } else if (status == "rejected") {
        rejected++;
      }
    }

    return {
      "pending": pending,
      "approved": approved,
      "rejected": rejected,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications screen coming soon.'),
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
                          "Rejected (${counts["rejected"]})",
                          selectedStatus == "rejected",
                          () {
                          setState(() => selectedStatus = "rejected");
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

          const SizedBox(height: 16),

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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: visibleApplications.length,
                        itemBuilder: (context, i) {
                          final a = visibleApplications[i];
                          return ApplicationCard(
                            name: a["name"] ?? "Unknown",
                            location: a["city"] ?? "-",
                            status: _normalizedStatus(a),
                            appliedAt: a["applied_at"],
                            applicationId: a["id"],
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
  final dynamic appliedAt;
  final int applicationId;
  final VoidCallback onRefresh;

  const ApplicationCard({
    super.key,
    required this.name,
    required this.location,
    required this.status,
    required this.appliedAt,
    required this.applicationId,
    required this.onRefresh,
  });

  String get statusLabel {
    switch (status) {
      case "approved":
        return "APPROVED";
      case "rejected":
        return "REJECTED";
      case "pending":
      default:
        return "PENDING";
    }
  }

  Color get statusColor {
    switch (status) {
      case "approved":
        return Colors.green.shade700;
      case "rejected":
        return Colors.red.shade700;
      case "pending":
      default:
        return Colors.orange.shade700;
    }
  }

  String get appliedDateText {
    if (appliedAt == null) return "Applied: -";
    final parsed = DateTime.tryParse(appliedAt.toString());
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
                    Text(
                      appliedDateText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "📍 $location",
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ViewApplicationScreen(applicationId: applicationId),
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
