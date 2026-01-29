import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'admin_users_screen.dart';
import 'admin_events_screen.dart';
import 'admin_applications_screen.dart';
import '../../services/admin_service.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late Future<Map<String, dynamic>> statsFuture;
  DateTime? lastUpdated;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      statsFuture = AdminService.getStats().then((data) {
        if (mounted) {
          setState(() => lastUpdated = DateTime.now());
        }
        return data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final updatedText = _formatLastUpdated(lastUpdated);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: AppBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Last updated: $updatedText"),
                    const SizedBox(height: 8),
                    Expanded(child: _skeletonGrid()),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Failed to load stats"));
            }

            final s = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Last updated: $updatedText"),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminUsersScreen(),
                              ),
                            );
                          },
                          child: statCard("Users", s["totalUsers"]),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminEventsScreen(),
                              ),
                            );
                          },
                          child: statCard("Events", s["totalEvents"]),
                        ),
                        statCard("Active Events", s["activeEvents"]),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminApplicationsScreen(),
                              ),
                            );
                          },
                          child:
                              statCard("Applications", s["totalApplications"]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget statCard(String title, int value) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _skeletonGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: List.generate(4, (index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 28,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatLastUpdated(DateTime? value) {
    if (value == null) return "Last updated: -";
    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inSeconds < 10) return "Last updated: just now";
    if (diff.inSeconds < 60) {
      return "Last updated: ${diff.inSeconds}s ago";
    }
    if (diff.inMinutes < 60) {
      return "Last updated: ${diff.inMinutes}m ago";
    }
    if (diff.inHours < 24) {
      return "Last updated: ${diff.inHours}h ago";
    }
    return "Last updated: ${value.toLocal()}".split(".")[0];
  }
}
