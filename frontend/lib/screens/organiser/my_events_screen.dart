import 'package:flutter/material.dart';
import '../../services/event_service.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List events = [];
  bool loading = true;

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

  // ================= DATE HELPERS =================

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  List _ongoingEvents() {
    final today = _onlyDate(DateTime.now());
    return events.where((e) {
      final d = _onlyDate(DateTime.parse(e["event_date"]));
      return d.isAtSameMomentAs(today);
    }).toList();
  }

  List _upcomingEvents() {
    final today = _onlyDate(DateTime.now());
    return events.where((e) {
      final d = _onlyDate(DateTime.parse(e["event_date"]));
      return d.isAfter(today);
    }).toList();
  }

  List _completedEvents() {
    final today = _onlyDate(DateTime.now());
    return events.where((e) {
      final d = _onlyDate(DateTime.parse(e["event_date"]));
      return d.isBefore(today);
    }).toList();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final ongoing = _ongoingEvents();
    final upcoming = _upcomingEvents();
    final completed = _completedEvents();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Events"),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? const Center(
                  child: Text(
                    "Your created events will appear here",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _section("Ongoing Events", ongoing),
                    _section("Upcoming Events", upcoming),
                    _section("Completed Events", completed),
                  ],
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
}
