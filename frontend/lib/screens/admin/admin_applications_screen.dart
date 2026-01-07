import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  // ✅ ADDED (as requested)
  String status = "all";

  late Future<List<dynamic>> appsFuture;

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

        // ✅ ADDED: filter applications by status
        final filtered = apps.where((a) =>
            status == "all" || a["status"] == status).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text("No applications found"));
        }

        // ✅ ADDED: extracted applications list
        final appsList = ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final a = filtered[i];

            return Card(
              child: ListTile(
                title: Text(a["event_title"]),
                subtitle: Text(
                  "${a["volunteer_name"]} • ${a["status"]}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () async {
                    await AdminService.cancelApplication(a["id"]);
                    refresh();
                  },
                ),
              ),
            );
          },
        );

        // ✅ UPDATED: wrap list with Column
        return Column(
          children: [
            DropdownButton<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: "all", child: Text("All")),
                DropdownMenuItem(value: "pending", child: Text("Pending")),
                DropdownMenuItem(value: "approved", child: Text("Approved")),
                DropdownMenuItem(value: "rejected", child: Text("Rejected")),
              ],
              onChanged: (v) => setState(() => status = v!),
            ),
            Expanded(child: appsList),
          ],
        );
      },
    );
  }
}
