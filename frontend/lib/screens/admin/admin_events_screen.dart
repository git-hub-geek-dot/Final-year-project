import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  late Future<List<dynamic>> eventsFuture;

  @override
  void initState() {
    super.initState();
    eventsFuture = AdminService.getAllEvents();
  }

  void refresh() {
    setState(() {
      eventsFuture = AdminService.getAllEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Failed to load events"));
        }

        final events = snapshot.data!;

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];

            return Card(
              child: ListTile(
                title: Text(e["title"]),
                subtitle: Text("Organiser: ${e["organizer_name"] ?? "N/A"}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await AdminService.deleteEvent(e["id"]);
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
