import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import '../../services/admin_service.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final List<dynamic> events = [];
  bool loading = true;
  bool loadingMore = false;
  int page = 1;
  int totalPages = 1;
  String search = "";

  @override
  void initState() {
    super.initState();
    _fetchEvents(reset: true);
  }

  Future<void> _fetchEvents({bool reset = false}) async {
    if (loadingMore) return;
    if (reset) {
      setState(() {
        loading = true;
        page = 1;
        totalPages = 1;
        events.clear();
      });
    } else {
      setState(() => loadingMore = true);
    }

    try {
      final data = await AdminService.getAllEvents(page: page, limit: 20);
      final items = (data["items"] as List?) ?? [];
      setState(() {
        events.addAll(items);
        totalPages = data["totalPages"] ?? 1;
        loading = false;
        loadingMore = false;
        page += 1;
      });
    } catch (_) {
      setState(() {
        loading = false;
        loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Events"),
      ),
      body: AppBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (context) {
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
                                itemCount: filtered.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == filtered.length) {
                                    final canLoadMore = page <= totalPages;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: canLoadMore
                                            ? ElevatedButton(
                                                onPressed: loadingMore
                                                    ? null
                                                    : () => _fetchEvents(),
                                                child: loadingMore
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Text("Load More"),
                                              )
                                            : const Text("No more events"),
                                      ),
                                    );
                                  }

                                  final event = filtered[i];
                                  final isDeleted =
                                      event["status"] == "deleted";

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
                                                  _fetchEvents(reset: true);
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
              ),
      ),
    );
  }
}
