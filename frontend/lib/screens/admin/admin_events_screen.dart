import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  // ✅ ADDED (as requested)
  String search = "";

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

        // ✅ ADDED: filter events before ListView
        final filtered = events
            .where((e) =>
                e["title"].toLowerCase().contains(search))
            .toList();

        // ✅ ADDED: extracted events list
        final eventsList = ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final e = filtered[i];

            return Card(
              child: ListTile(
                title: Text(e["title"]),
                subtitle:
                    Text("Organiser: ${e["organizer_name"] ?? "N/A"}"),
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

        // ✅ UPDATED: wrap list with Column
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search event title",
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => search = v.toLowerCase()),
              ),
            ),
            Expanded(child: eventsList),
          ],
        );
      },
    );
  }
}
