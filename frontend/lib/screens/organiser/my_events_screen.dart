import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import 'event_details_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List events = [];
  bool loading = true;
  int _selectedFilter = 0; // 0: All, 1: Upcoming, 2: Ongoing, 3: Completed
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadEvents();
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
        const SnackBar(content: Text("Failed to load events")),
      );
    }
  }

  String _getStatus(Map event) =>
      event["computed_status"] ?? event["status"] ?? "upcoming";

  List _getFilteredEvents() {
    var filtered = events.where((e) {
      final status = _getStatus(e);
      switch (_selectedFilter) {
        case 1:
          return status == "upcoming";
        case 2:
          return status == "ongoing";
        case 3:
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
        title: const Text("My Events"),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        _statCard("${stats['total']}", "Total"),
                        _statCard("${stats['upcoming']}", "Upcoming"),
                        _statCard("${stats['ongoing']}", "Ongoing"),
                        _statCard("${stats['completed']}", "Completed"),
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
                        hintText: "Search events...",
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
                          _filterTab("All", 0),
                          const SizedBox(width: 8),
                          _filterTab("Upcoming", 1),
                          const SizedBox(width: 8),
                          _filterTab("Ongoing", 2),
                          const SizedBox(width: 8),
                          _filterTab("Completed", 3),
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
                          "No events found",
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
                                          color:
                                              statusColor.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        event["event_date"]
                                            .toString()
                                            .split("T")[0],
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
                                          event["title"] ?? "Untitled",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "📍 ${event["location"] ?? "N/A"}",
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

  // ================= SECTION =================

  Widget _section(String title, List list) {
    if (list.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...list.map((event) => _eventCard(event)),
      ],
    );
  }

  // ================= EVENT CARD =================

  Widget _eventCard(dynamic event) {
    final eventDate = event["event_date"] != null
        ? event["event_date"].toString().split("T")[0]
        : "-";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 1,
      child: ListTile(
        title: Text(
          event["title"] ?? "Untitled Event",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("📍 ${event["location"] ?? "-"}"),
            const SizedBox(height: 4),
            Text(
              "Status: ${event["status"] ?? "open"}",
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        trailing: Text(
          eventDate,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
