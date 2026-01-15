import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  late Future<List<dynamic>> appsFuture;
  String statusFilter = "all";

  @override
  void initState() {
    super.initState();
    appsFuture = AdminService.getAllApplications();
  }

  void refresh() {
    setState(() {
      appsFuture = AdminService.getAllApplications();
    });
  }

  Color statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      case "pending":
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: appsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Failed to load applications"));
        }

        final apps = snapshot.data!;

        final filtered = apps.where((a) {
          return statusFilter == "all" || a["status"] == statusFilter;
        }).toList();

        return Column(
          children: [
            // 🔽 Status filter
            Padding(
              padding: const EdgeInsets.all(8),
              child: DropdownButton<String>(
                value: statusFilter,
                items: const [
                  DropdownMenuItem(
                      value: "all", child: Text("All Applications")),
                  DropdownMenuItem(
                      value: "pending", child: Text("Pending")),
                  DropdownMenuItem(
                      value: "approved", child: Text("Approved")),
                  DropdownMenuItem(
                      value: "cancelled", child: Text("Cancelled")),
                ],
                onChanged: (v) => setState(() => statusFilter = v!),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No applications found"))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final app = filtered[i];
                        final isCancelled = app["status"] == "cancelled";

                        return Card(
                          child: ListTile(
                            title: Text(app["event_title"]),
                            subtitle: Text(
                              "${app["volunteer_name"]} • ${app["status"]}",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor(app["status"]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    app["status"],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                                // ❌ Cancel button (only if not cancelled)
                                if (!isCancelled)
                                  IconButton(
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final confirm =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title:
                                              const Text("Cancel Application"),
                                          content: const Text(
                                              "Are you sure you want to cancel this application?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text("No"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text("Yes"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await AdminService.cancelApplication(
                                            app["id"]);
                                        refresh();
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
