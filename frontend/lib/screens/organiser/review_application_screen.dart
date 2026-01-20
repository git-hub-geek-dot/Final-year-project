import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import 'view_application_screen.dart';

class ReviewApplicationsScreen extends StatefulWidget {
  final int eventId;

  const ReviewApplicationsScreen({super.key, required this.eventId});

  @override
  State<ReviewApplicationsScreen> createState() =>
      _ReviewApplicationsScreenState();
}

class _ReviewApplicationsScreenState extends State<ReviewApplicationsScreen> {
  bool showActive = true;
  bool loading = true;
  List applications = [];

  @override
  void initState() {
    super.initState();
    loadApplications();
  }

  Future<void> loadApplications() async {
    try {
      final data = await EventService.fetchApplications(widget.eventId);
      setState(() {
        applications = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  List get filtered {
    if (showActive) {
      return applications
          .where((a) => (a["status"] ?? "pending") == "pending")
          .toList();
    } else {
      return applications
          .where((a) => (a["status"] ?? "") != "pending")
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              children: const [
                Text(
                  "Volunteerx",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🔘 Active / Inactive Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                toggleButton("Active", showActive, () {
                  setState(() => showActive = true);
                }),
                const SizedBox(width: 10),
                toggleButton("Inactive", !showActive, () {
                  setState(() => showActive = false);
                }),
                const Spacer(),
                const Text("Sort By: Newest"),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 📋 Applications List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text("No applications yet"))
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final a = filtered[i];
                          return ApplicationCard(
                            name: a["name"] ?? "Unknown",
                            location: a["city"] ?? "-",
                            applicationId: a["id"],
                            onRefresh: loadApplications,
                          );
                        },
                      ),
          ),
        ],
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
  final int applicationId;
  final VoidCallback onRefresh;

  const ApplicationCard({
    super.key,
    required this.name,
    required this.location,
    required this.applicationId,
    required this.onRefresh,
  });

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
