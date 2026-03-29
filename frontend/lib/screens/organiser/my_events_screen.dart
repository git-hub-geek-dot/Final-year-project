import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import '../../services/notification_service.dart';
import '../../utils/ist_date_time.dart';
import 'event_details_screen.dart';
import '../../localization/localization_extensions.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List events = [];
  bool loading = true;
  int _selectedFilter =
      0; // 0: All, 1: Draft, 2: Cancelled, 3: Upcoming, 4: Ongoing, 5: Completed
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    loadEvents();
    _notificationSub =
        NotificationService.messageEvents.listen(_handleNotificationEvent);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleNotificationEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = (data["type"] ?? "").toString().trim().toLowerCase();
    if (type == "event_removed" || type == "event_deleted") {
      loadEvents();
    }
  }

  Future<void> loadEvents() async {
    try {
      final data = await EventService.fetchMyEvents();
      setState(() {
        events = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to load events"))),
      );
    }
  }

  String _getStatus(Map event) {
    final status = (event["computed_status"] ?? event["status"] ?? "upcoming")
        .toString()
        .toLowerCase();
    if (status == "closed") return "cancelled";
    if (status == "deleted" || status == "deleted_by_admin") {
      return "deleted_by_admin";
    }
    return status;
  }

  String _statusLabel(String status) {
    switch (status) {
      case "upcoming":
        return "Upcoming";
      case "ongoing":
        return "Ongoing";
      case "draft":
        return "Draft";
      case "cancelled":
        return "Cancelled";
      case "completed":
        return "Completed";
      case "deleted_by_admin":
        return "Removed";
      default:
        return status;
    }
  }

  List _getFilteredEvents() {
    var filtered = events.where((e) {
      final status = _getStatus(e);
      switch (_selectedFilter) {
        case 1:
          return status == "draft";
        case 2:
          return status == "cancelled";
        case 3:
          return status == "upcoming";
        case 4:
          return status == "ongoing";
        case 5:
          return status == "completed";
        default:
          return true;
      }
    }).toList();

    if (_searchQuery.isEmpty) return filtered;
    return filtered
        .where((e) =>
            (e["title"] ?? "").toString().toLowerCase().contains(_searchQuery))
        .toList();
  }

  Map<String, int> _getStats() {
    return {
      "total": events.length,
      "draft": events.where((e) => _getStatus(e) == "draft").length,
      "cancelled": events.where((e) => _getStatus(e) == "cancelled").length,
      "upcoming": events.where((e) => _getStatus(e) == "upcoming").length,
      "ongoing": events.where((e) => _getStatus(e) == "ongoing").length,
      "completed": events.where((e) => _getStatus(e) == "completed").length,
    };
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final stats = _getStats();
    final filtered = _getFilteredEvents();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("My Events")),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadEvents,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 📊 STATS HEADER
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statCard("${stats['total']}", context.tr("Total")),
                          _statCard("${stats['draft']}", context.tr("Draft")),
                          _statCard(
                            "${stats['cancelled']}",
                            context.tr("Cancelled"),
                          ),
                          _statCard(
                            "${stats['upcoming']}",
                            context.tr("Upcoming"),
                          ),
                          _statCard(
                            "${stats['ongoing']}",
                            context.tr("Ongoing"),
                          ),
                          _statCard(
                            "${stats['completed']}",
                            context.tr("Completed"),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔍 SEARCH BAR
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: context.tr("Search events..."),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 📑 FILTER TABS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterTab(context.tr("All"), 0),
                            const SizedBox(width: 8),
                            _filterTab(context.tr("Draft"), 1),
                            const SizedBox(width: 8),
                            _filterTab(context.tr("Cancelled"), 2),
                            const SizedBox(width: 8),
                            _filterTab(context.tr("Upcoming"), 3),
                            const SizedBox(width: 8),
                            _filterTab(context.tr("Ongoing"), 4),
                            const SizedBox(width: 8),
                            _filterTab(context.tr("Completed"), 5),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 📋 EVENT LIST
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            context.tr("No events found"),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: filtered.map((event) {
                            final status = _getStatus(event);
                            final statusColor = status == "upcoming"
                                ? Colors.blue
                                : status == "ongoing"
                                    ? Colors.orange
                                    : status == "draft"
                                        ? Colors.grey
                                        : status == "deleted_by_admin"
                                            ? Colors.blueGrey
                                        : status == "cancelled"
                                            ? Colors.red
                                            : Colors.green;

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EventDetailsScreen(event: event),
                                  ),
                                ).then((_) => loadEvents());
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            context.tr(_statusLabel(status)),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                          Text(
                                            IstDateTime.formatDate(
                                              event["event_date"],
                                            ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event["title"] ??
                                                context.tr("Untitled"),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "📍 ${event["location"] ?? context.tr("N/A")}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                "👥 ${event["volunteers_required"] ?? 0}",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              if (event["rating"] != null) ...[
                                                const SizedBox(width: 12),
                                                const Icon(Icons.star,
                                                    size: 12,
                                                    color: Colors.amber),
                                                const SizedBox(width: 2),
                                                Text(
                                                  "${event["rating"]}",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios,
                                        size: 14, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _filterTab(String label, int index) {
    final isActive = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

}
