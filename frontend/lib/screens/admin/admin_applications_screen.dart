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

        if (apps.isEmpty) {
          return const Center(child: Text("No applications found"));
        }

        return ListView.builder(
          itemCount: apps.length,
          itemBuilder: (context, i) {
            final a = apps[i];

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
      },
    );
  }
}
