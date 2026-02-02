import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'package:frontend/widgets/error_state.dart';
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
  String? errorMessage;
  String search = "";
  String sortField = "event_date"; // title | status | event_date
  bool sortAsc = true;

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
        errorMessage = null;
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
        errorMessage = null;
      });
    } catch (_) {
      setState(() {
        loading = false;
        loadingMore = false;
        if (reset) {
          errorMessage = "Failed to load events";
        }
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
          : errorMessage != null
            ? ErrorState(
              message: errorMessage!,
              onRetry: () => _fetchEvents(reset: true),
              )
            : Builder(
                builder: (context) {
                  final filtered = events.where((e) {
                    return e["title"]
                        .toString()
                        .toLowerCase()
                        .contains(search.toLowerCase());
                  }).toList()
                    ..sort((a, b) => _compareEvents(a, b));

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

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            DropdownButton<String>(
                              value: sortField,
                              items: const [
                                DropdownMenuItem(
                                    value: "event_date", child: Text("Event Date")),
                                DropdownMenuItem(
                                    value: "title", child: Text("Title")),
                                DropdownMenuItem(
                                    value: "status", child: Text("Status")),
                              ],
                              onChanged: (v) =>
                                  setState(() => sortField = v!),
                            ),
                            IconButton(
                              icon: Icon(
                                sortAsc
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                              ),
                              onPressed: () =>
                                  setState(() => sortAsc = !sortAsc),
                            ),
                          ],
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

  int _compareEvents(Map a, Map b) {
    int result;
    switch (sortField) {
      case "title":
        result = (a["title"] ?? "").toString().toLowerCase().compareTo(
            (b["title"] ?? "").toString().toLowerCase());
        break;
      case "status":
        result = (a["status"] ?? "").toString().compareTo(
            (b["status"] ?? "").toString());
        break;
      case "event_date":
      default:
        final aDate = DateTime.tryParse((a["event_date"] ?? "").toString());
        final bDate = DateTime.tryParse((b["event_date"] ?? "").toString());
        result = (aDate ?? DateTime(1970))
            .compareTo(bDate ?? DateTime(1970));
        break;
    }

    return sortAsc ? result : -result;
  }

}
