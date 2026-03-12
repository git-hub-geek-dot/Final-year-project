import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'package:frontend/widgets/error_state.dart';
import '../../services/admin_service.dart';
import '../../utils/ist_date_time.dart';
import 'admin_event_details_screen.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

enum _DeleteAction { soft, hard }

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final List<dynamic> events = [];
  bool loading = true;
  String? errorMessage;
  String search = "";
  String sortField = "event_date"; // title | status | event_date
  bool sortAsc = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents(reset: true);
  }

  Future<void> _confirmDelete(Map event) async {
    final action = await showDialog<_DeleteAction>(
      context: context,
      builder: (context) {
        bool confirmHardDelete = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Delete event"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose delete type for \"${event["title"]}\".\n\n"
                    "Soft delete hides the event. Hard delete removes it permanently.",
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: confirmHardDelete,
                        onChanged: (value) => setDialogState(
                            () => confirmHardDelete = value ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          "I understand hard delete is permanent.",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _DeleteAction.soft),
                  child: const Text("Soft Delete"),
                ),
                TextButton(
                  onPressed: confirmHardDelete
                      ? () => Navigator.pop(context, _DeleteAction.hard)
                      : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Hard Delete"),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == null) return;

    try {
      if (action == _DeleteAction.soft) {
        await AdminService.deleteEvent(event["id"]);
      } else {
        await AdminService.hardDeleteEvent(event["id"]);
      }
      _fetchEvents(reset: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Delete failed")),
      );
    }
  }

  Future<void> _fetchEvents({bool reset = false}) async {
    if (reset) {
      setState(() {
        loading = true;
        events.clear();
        errorMessage = null;
      });
    }

    try {
      final allItems = <dynamic>[];
      int currentPage = 1;
      int lastPage = 1;

      do {
        final data = await AdminService.getAllEvents(
          page: currentPage,
          limit: 20,
        );
        final items = (data["items"] as List?) ?? [];
        lastPage = data["totalPages"] ?? currentPage;
        allItems.addAll(items);
        currentPage += 1;
      } while (currentPage <= lastPage);

      if (!mounted) return;
      setState(() {
        events
          ..clear()
          ..addAll(allItems);
        loading = false;
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
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
                                        value: "event_date",
                                        child: Text("Event Date")),
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
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final event = filtered[i];
                                      final isDeleted =
                                          event["status"] == "deleted";

                                      return Opacity(
                                        opacity: isDeleted ? 0.4 : 1.0,
                                        child: Card(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AdminEventDetailsScreen(
                                                          event: event),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Title and Status Row
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          (event["title"] ?? "")
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            decoration: isDeleted
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isDeleted)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .red.shade100,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Text(
                                                            "DELETED",
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .red.shade700,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),

                                                  // Organiser and Date Row
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          size: 16,
                                                          color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          "Organiser: ${event["organiser_name"] ?? event["organizer_name"] ?? "N/A"}",
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),

                                                  Row(
                                                    children: [
                                                      Icon(Icons.calendar_today,
                                                          size: 16,
                                                          color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatEventDate(event[
                                                            "event_date"]),
                                                        style: const TextStyle(
                                                            color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),

                                                  // Actions Row
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      if (!isDeleted)
                                                        TextButton.icon(
                                                          onPressed: () async {
                                                            await _confirmDelete(
                                                                event);
                                                          },
                                                          icon: const Icon(
                                                              Icons.delete,
                                                              size: 16),
                                                          label: const Text(
                                                              "Delete"),
                                                          style: TextButton
                                                              .styleFrom(
                                                            foregroundColor:
                                                                Colors.red,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        8),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
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

  String _formatEventDate(String? dateString) {
    if (dateString == null) return "Date TBA";
    final date = IstDateTime.tryParse(dateString);
    if (date == null) return "Invalid Date";

    final today = IstDateTime.startOfDay(IstDateTime.now());
    final eventDate = IstDateTime.startOfDay(date);

    if (eventDate == today) {
      return "Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return "Tomorrow, ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.day}/${date.month}/${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
  }

  int _compareEvents(Map a, Map b) {
    int result;
    switch (sortField) {
      case "title":
        result = (a["title"] ?? "")
            .toString()
            .toLowerCase()
            .compareTo((b["title"] ?? "").toString().toLowerCase());
        break;
      case "status":
        result = (a["status"] ?? "")
            .toString()
            .compareTo((b["status"] ?? "").toString());
        break;
      case "event_date":
      default:
        final aDate = IstDateTime.tryParse((a["event_date"] ?? "").toString());
        final bDate = IstDateTime.tryParse((b["event_date"] ?? "").toString());
        result = (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
        break;
    }

    return sortAsc ? result : -result;
  }
}
