import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import 'create_event_screen.dart';
import 'leaderboard_screen.dart';
import 'review_application_screen.dart';
import 'event_details_screen.dart';

class OrganiserHomeScreen extends StatefulWidget {
  const OrganiserHomeScreen({super.key});

  @override
  State<OrganiserHomeScreen> createState() => _OrganiserHomeScreenState();
}

class _OrganiserHomeScreenState extends State<OrganiserHomeScreen> {
  bool loading = true;
  List events = [];

  @override
  void initState() {
    super.initState();
    loadMyEvents();
  }

  Future<void> loadMyEvents() async {
    try {
      final data = await EventService.fetchMyEvents();
      setState(() {
        events = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  String _status(Map e) => e["computed_status"] ?? e["status"] ?? "upcoming";

  List getUpcomingEvents() =>
      events.where((e) => _status(e) == "upcoming").toList();

  List getOngoingEvents() =>
      events.where((e) => _status(e) == "ongoing").toList();

  List getCompletedEvents() =>
      events.where((e) => _status(e) == "completed").toList();

  List getDeletedEvents() =>
    events.where((e) => _status(e) == "deleted_by_admin").toList();


  @override
  Widget build(BuildContext context) {
    final upcoming = getUpcomingEvents();
    final ongoing = getOngoingEvents();
    final completed = getCompletedEvents();

    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Volunteerx",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateEventScreen()),
                ).then((_) => loadMyEvents());
              },
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "Create Event",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _section("Ongoing Events", ongoing),
                      _section("Upcoming Events", upcoming),
                      _section("Completed Events", completed),
                      _section("Deleted Events", getDeletedEvents()),
                    ],
                  ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatItem(events.length.toString(), "Total"),
                  StatItem(ongoing.length.toString(), "Ongoing"),
                  StatItem(upcoming.length.toString(), "Upcoming"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            );
          } else if (index == 2) {
            Navigator.pushNamed(context, "/organiser-profile");
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: "Leaderboard"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _section(String title, List list) {
    if (list.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...list.map((event) => eventCard(context, event, loadMyEvents)),
      ],
    );
  }
}

Widget eventCard(
  BuildContext context,
  Map event,
  VoidCallback onRefresh,
) {
  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen(event: event),
        ),
      ).then((updated) {
        if (updated == true) {
          onRefresh();
        }
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event["title"] ?? "Untitled",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("📍 ${event["location"] ?? ""}"),
            Text("📅 ${event["event_date"].toString().split("T")[0]}"),
          ]),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReviewApplicationsScreen(eventId: event["id"]),
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Review Applications",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class StatItem extends StatelessWidget {
  final String value;
  final String label;

  const StatItem(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
