import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'volunteer_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'view_event_screen.dart'; // ✅ ADDED
import '../../config/api_config.dart';


class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
  
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  
  int selectedIndex = 0;
  List events = [];
  bool loading = true;

  String searchQuery = "";


  // 🔹 FILTER UI STATE (UNCHANGED)
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
    await http.get(Uri.parse("${ApiConfig.baseUrl}/events"));


    debugPrint("==== EVENTS API CALL ====");
    debugPrint("STATUS CODE: ${response.statusCode}");
    debugPrint("RAW BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      debugPrint("DECODED TYPE: ${decoded.runtimeType}");
      debugPrint("DECODED LENGTH: ${decoded.length}");

      setState(() {
        events = decoded;
        loading = false;
      });
    } else {
      debugPrint("NON-200 RESPONSE");
      setState(() => loading = false);
    }
  } catch (e) {
    debugPrint("FETCH EVENTS ERROR: $e");
    setState(() => loading = false);
  }
}


  // ================= TAB BODY =================
  Widget getBody() {
    if (selectedIndex == 0) {
      return buildHome();
    } else if (selectedIndex == 1) {
      return const LeaderboardScreen();
    } else {
      return const VolunteerProfileScreen();
    }
  }

  // ================= HOME UI =================
  Widget buildHome() {
  if (loading) {
    return const Center(child: CircularProgressIndicator());
  }

  // ✅ THIS IS THE FIX
  final filteredEvents = events.where((e) {
  final title = (e["title"] ?? "").toString().toLowerCase();
  final location = (e["location"] ?? "").toString().toLowerCase();

  final matchesSearch =
      title.contains(searchQuery) || location.contains(searchQuery);

  final matchesCategory =
      selectedCategory == "All" || e["category"] == selectedCategory;

  // ✅ PAID / UNPAID LOGIC
  final payment = e["payment_per_day"];
  final isPaid = payment != null && payment > 0;

  bool matchesPayment = true;
  if (filterPaid && !filterUnpaid) {
    matchesPayment = isPaid;
  } else if (!filterPaid && filterUnpaid) {
    matchesPayment = !isPaid;
  }

  return matchesSearch && matchesCategory && matchesPayment;
}).toList();



  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔍 Search + Filter (UNCHANGED)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                
                  onChanged: (value) {
                setState(() {
                searchQuery = value.toLowerCase();
                      });
                        },
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
                child: const Row(
                  children: [
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
            ),
          ],
        ),
      ),

      // 🟦 CATEGORY CHIPS (UNCHANGED)
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

      // 📋 EVENTS LIST (✅ FIXED)
      Expanded(
        child: filteredEvents.isEmpty
            ? const Center(child: Text("No events found"))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredEvents.length,
                itemBuilder: (context, index) {
                  final event = filteredEvents[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewEventScreen(event: event),
                        ),
                      );
                    },
                    child: eventCard(
                      title: event["title"] ?? "",
                      location: event["location"] ?? "",
                      date: event["event_date"]
                              ?.toString()
                              .split("T")[0] ??
                          "",
                      slotsLeft: event["slots_left"] ?? 0,
                    ),
                  );
                },
              ),
      ),
    ],
  );
}


  // ================= FILTER BOTTOM SHEET (UNCHANGED) =================
  void _openFilterSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true, // ✅ FIX 1: forces visible height
    backgroundColor: Colors.white, // ✅ FIX 2: avoids transparent sheet
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea( // ✅ FIX 3: prevents zero-height rendering
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    onChanged: (v) =>
                        setSheetState(() => filterPaid = v!),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  CheckboxListTile(
                    title: const Text("Unpaid"),
                    value: filterUnpaid,
                    onChanged: (v) =>
                        setSheetState(() => filterUnpaid = v!),
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
        title: const Text(
          "VolunteerX",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: getBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: "Leaderboard"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ================= EVENT CARD (HOME) =================
Widget eventCard({
  required String title,
  required String location,
  required String date,
  required int slotsLeft,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFFEAF0FF), Color(0xFFF2FFF7)],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🟢 SLOTS LEFT BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: slotsLeft > 0 ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$slotsLeft left",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // EVENT INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(location,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
