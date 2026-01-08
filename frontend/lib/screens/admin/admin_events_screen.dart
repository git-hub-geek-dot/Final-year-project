import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  late Future<List<dynamic>> eventsFuture;
  String search = "";

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

        final filtered = events.where((e) {
          return e["title"]
              .toString()
              .toLowerCase()
              .contains(search.toLowerCase());
        }).toList();

        return Column(
          children: [
            // 🔍 Search
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search event title",
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No events found"))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final event = filtered[i];
                        final isDeleted = event["status"] == "deleted";

                        return Opacity(
                          opacity: isDeleted ? 0.4 : 1.0,
                          child: Card(
                            child: ListTile(
                              title: Text(
                                isDeleted
                                    ? "${event["title"]} (Deleted)"
                                    : event["title"],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                "Organiser: ${event["organiser_name"] ?? "N/A"}",
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: isDeleted
                                    ? null
                                    : () async {
                                        await AdminService.deleteEvent(
                                          event["id"],
                                        );
                                        refresh();
                                      },
                              ),
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
