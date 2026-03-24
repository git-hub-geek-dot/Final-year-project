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
  String statusFilter = "all"; // all | upcoming | ongoing | completed | cancelled | removed | draft

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
                        final title = e["title"].toString().toLowerCase();
                        final matchesSearch = title.contains(search.toLowerCase());
                        if (!matchesSearch) return false;

                        if (statusFilter == "all") return true;
                        final eventStatus = _normalizedEventStatus(e);
                        if (statusFilter == "removed") {
                          return eventStatus == "deleted_by_admin";
                        }
                        return eventStatus == statusFilter;
                      }).toList();

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
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _statusChip("All", "all"),
                                  _statusChip("Upcoming", "upcoming"),
                                  _statusChip("Ongoing", "ongoing"),
                                  _statusChip("Completed", "completed"),
                                  _statusChip("Cancelled", "cancelled"),
                                  _statusChip("Removed", "removed"),
                                  _statusChip("Draft", "draft"),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: filtered.isEmpty
                                ? const Center(child: Text("No events found"))
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final event = filtered[i];
                                      final eventStatus =
                                          _normalizedEventStatus(event);
                                      final statusLabel =
                                          _eventStatusLabel(eventStatus);
                                      final statusColor =
                                          _eventStatusColor(eventStatus);
                                      final isDeleted =
                                          eventStatus == "deleted_by_admin";

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
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: statusColor
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12),
                                                        ),
                                                        child: Text(
                                                          statusLabel
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: statusColor,
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
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.access_time,
                                                          size: 16,
                                                          color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatEventTimeRange(
                                                            event),
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
      return "Today";
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return "Tomorrow";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  String _formatEventTimeRange(Map event) {
    final directStart = _timeOrNull(event["start_time"] ?? event["startTime"]);
    final directEnd = _timeOrNull(event["end_time"] ?? event["endTime"]);
    if (directStart != null && directEnd != null) {
      return "$directStart-$directEnd";
    }

    final schedules = event["daily_schedules"];
    if (schedules is List && schedules.isNotEmpty) {
      final first = schedules.first;
      if (first is Map) {
        final scheduleStart =
            _timeOrNull(first["start_time"] ?? first["startTime"]);
        final scheduleEnd = _timeOrNull(first["end_time"] ?? first["endTime"]);
        if (scheduleStart != null && scheduleEnd != null) {
          return "$scheduleStart-$scheduleEnd";
        }
      }
    }

    return "Time TBA";
  }

  String? _timeOrNull(dynamic raw) {
    final formatted = IstDateTime.formatTime(raw);
    if (formatted == "-" || formatted.trim().isEmpty) return null;
    return formatted;
  }

  String _normalizedEventStatus(Map event) {
    final raw = (event["computed_status"] ?? event["status"] ?? "")
        .toString()
        .toLowerCase();
    if (raw == "closed") return "cancelled";
    if (raw == "deleted" || raw == "deleted_by_admin") {
      return "deleted_by_admin";
    }
    return raw.isEmpty ? "open" : raw;
  }

  Widget _statusChip(String label, String value) {
    final selected = statusFilter == value;
    final displayValue = value == "removed" ? "deleted_by_admin" : value;
    final color = _eventStatusColor(displayValue);

    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.18),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? color : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected ? color : Colors.black12,
        ),
        onSelected: (_) => setState(() => statusFilter = value),
      ),
    );
  }

  String _eventStatusLabel(String status) {
    switch (status) {
      case "upcoming":
        return "Upcoming";
      case "ongoing":
        return "Ongoing";
      case "completed":
        return "Completed";
      case "cancelled":
        return "Cancelled";
      case "deleted_by_admin":
        return "Removed";
      case "draft":
        return "Draft";
      case "open":
      default:
        return "Open";
    }
  }

  Color _eventStatusColor(String status) {
    switch (status) {
      case "upcoming":
        return Colors.blue;
      case "ongoing":
      case "open":
        return Colors.green;
      case "completed":
        return Colors.grey;
      case "cancelled":
        return Colors.red;
      case "deleted_by_admin":
        return Colors.grey;
      case "draft":
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}
