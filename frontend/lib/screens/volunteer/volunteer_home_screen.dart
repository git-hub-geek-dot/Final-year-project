import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  // 🔹 FILTER UI STATE (UI ONLY)
  String selectedCategory = "All";
  bool filterPaid = false;
  bool filterUnpaid = false;

  final List<String> eventCategories = [
    "All",
    "Education",
    "Healthcare",
    "Environment",
    "Animals",
    "Community",
    "Charity",
    "Sports & Fitness",
    "Arts & Culture",
    "Technology",
    "Skill Development",
    "Social Awareness",
    "Disaster Relief",
    "Women & Child Welfare",
    "Senior Citizen Support",
    "Cleanliness Drives",
    "Food & Nutrition",
    "Fundraising",
    "Reception & Party Management",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  // ================= LOGIC UNCHANGED =================
  Future<void> fetchEvents() async {
    try {
      final response =
          await http.get(Uri.parse("http://10.0.2.2:4000/api/events"));

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

  // ================= UI (UNCHANGED) =================
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openFilterSheet,
                child: Container(
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
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 🟦 BLUE CATEGORY CHIPS (RESTORED)
        SizedBox(
          height: 46,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: eventCategories.length,
            itemBuilder: (context, index) {
              final category = eventCategories[index];
              final selected = category == selectedCategory;

              return GestureDetector(
                onTap: () {
                  setState(() => selectedCategory = category);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2E6BE6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Volunteer Jobs",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 12),

        // 📋 Events list (UNCHANGED UI)
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
                              content: Text("Apply feature coming soon")),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= FILTER BOTTOM SHEET (NEW, UI ONLY) =================
  void _openFilterSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // ✅ required for scrolling
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SingleChildScrollView( // ✅ ONLY ADDITION
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,

              // ⬇️ EVERYTHING BELOW IS YOUR EXISTING CODE
              children: [
                const Center(
                  child: Text(
                    "Filter Events",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Compensation",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                CheckboxListTile(
                  title: const Text("Paid"),
                  value: filterPaid,
                  onChanged: (val) =>
                      setSheetState(() => filterPaid = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                CheckboxListTile(
                  title: const Text("Unpaid"),
                  value: filterUnpaid,
                  onChanged: (val) =>
                      setSheetState(() => filterUnpaid = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 16),

                const Text(
                  "Categories",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: eventCategories
                      .where((c) => c != "All")
                      .map(
                        (cat) => ChoiceChip(
                          label: Text(cat),
                          selected: selectedCategory == cat,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedCategory = cat;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Apply Filters"),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
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
            ),
          ),
        ),
        title: const Text("VolunteerX",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: getBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ================= EVENT CARD (UNCHANGED) =================
Widget eventCard({
  required String title,
  required String location,
  required String date,
  required VoidCallback onApply,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(location, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(date, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(onPressed: onApply, child: const Text("Apply")),
        ),
      ]),
    ),
  );
}
