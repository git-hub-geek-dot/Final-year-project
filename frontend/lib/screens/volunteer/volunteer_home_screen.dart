import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_colors.dart';
import 'volunteer_profile_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  int selectedIndex = 0;
  List events = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  // ================= LOGIC UNCHANGED =================
  Future<void> fetchEvents() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:4000/api/events"),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          events = decoded;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Widget getBody() {
    return selectedIndex == 0
        ? buildHome()
        : const VolunteerProfileScreen();
  }

  // ================= UI ONLY =================
  Widget buildHome() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔍 Search + Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search volunteer jobs",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.tune, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Filter",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 🏷️ Category Chips (UI only)
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: const [
              _CategoryChip(label: "Education", selected: true),
              _CategoryChip(label: "Healthcare"),
              _CategoryChip(label: "Environment"),
              _CategoryChip(label: "Animals"),
              _CategoryChip(label: "Community"),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 📌 Section title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Volunteer Jobs",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 📋 Events list
        Expanded(
          child: events.isEmpty
              ? const Center(child: Text("No events available"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];

                    return eventCard(
                      title: event["title"] ?? "",
                      location: event["location"] ?? "",
                      date: event["event_date"]
                          .toString()
                          .split("T")[0],
                      onApply: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Apply feature coming soon"),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "VolunteerX",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Icon(Icons.notifications_none),
          SizedBox(width: 12),
        ],
      ),

      body: getBody(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() => selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// ================= CATEGORY CHIP (UI ONLY) =================
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _CategoryChip({
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2E6BE6) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ================= EVENT CARD (UI ONLY) =================
Widget eventCard({
  required String title,
  required String location,
  required String date,
  required VoidCallback onApply,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    elevation: 3,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            height: 160,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: const Icon(Icons.image, size: 60, color: Colors.white),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),

              const SizedBox(height: 6),

              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(location,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(date,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onApply,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2E6BE6),
                          Color(0xFF2ECC71),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      "Apply",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
