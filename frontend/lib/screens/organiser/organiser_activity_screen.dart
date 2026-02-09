import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/event_service.dart';

class OrganiserActivityScreen extends StatefulWidget {
  const OrganiserActivityScreen({super.key});

  @override
  State<OrganiserActivityScreen> createState() =>
      _OrganiserActivityScreenState();
}

class _OrganiserActivityScreenState extends State<OrganiserActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List _events = [];
  bool _loadingEvents = true;
  Timer? _eventsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadEvents();
    _tabController.addListener(_onTabChanged);
    _eventsRefreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _loadEvents(silent: true));
  }

  @override
  void dispose() {
    _eventsRefreshTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      _loadEvents(silent: true);
    }
  }

  Future<void> _loadEvents({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loadingEvents = true);
    }

    try {
      final data = await EventService.fetchMyEvents();
      if (!mounted) return;
      setState(() {
        _events = data;
        _loadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEvents = false);
    }
  }

  String _status(Map event) =>
      (event["computed_status"] ?? event["status"] ?? "upcoming").toString();

  String _dateText(dynamic value) {
    if (value == null) return "Date not set";
    final text = value.toString();
    if (text.isEmpty) return "Date not set";
    return text.split("T")[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          // 🔷 HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.business, size: 36),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your Organisation",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 📑 TABS
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: "Volunteers"),
                    Tab(text: "Events"),
                    Tab(text: "Rating"),
                    Tab(text: "Reviews"),
                  ],
                ),
              ],
            ),
          ),

          // 🧩 TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const Center(child: Text("Your volunteers will appear here")),

                RefreshIndicator(
                  onRefresh: () => _loadEvents(),
                  child: _loadingEvents
                      ? const Center(child: CircularProgressIndicator())
                      : _events.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 220),
                                Center(child: Text("No events found")),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _events.length,
                              itemBuilder: (context, index) {
                                final event = _events[index] as Map;
                                final status = _status(event);
                                final statusColor = status == "ongoing"
                                    ? Colors.orange
                                    : status == "completed"
                                        ? Colors.green
                                        : status == "draft"
                                            ? Colors.grey
                                            : Colors.blue;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (event["title"] ?? "Untitled Event").toString(),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              event["location"]?.toString().isNotEmpty == true
                                                  ? event["location"].toString()
                                                  : "Location not set",
                                              style: TextStyle(color: Colors.grey.shade700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _dateText(event["event_date"]),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),

                const Center(
                  child: Text(
                    "Your organisation rating",
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                const Center(child: Text("Volunteer reviews will appear here")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
