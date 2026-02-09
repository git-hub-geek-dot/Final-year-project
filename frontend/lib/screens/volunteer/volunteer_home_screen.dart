import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'volunteer_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'view_event_screen.dart'; // ✅ ADDED
import '../../config/api_config.dart';
import '../../services/saved_events_service.dart';
import '../../services/token_service.dart';
import '../chat/chat_inbox_screen.dart';


class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
  
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  
  int selectedIndex = 0;
  List events = [];
  List myApplications = [];
  bool loading = true;
  bool loadingApplications = true;
  Set<String> savedEventIds = {};
  
  String searchQuery = "";
  String selectedFeed = "all"; // all | confirmed | pending


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
    fetchMyApplications();
    _loadSavedEvents();
  }

  Future<void> fetchMyApplications() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          myApplications = [];
          loadingApplications = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/applications/my"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded is List ? decoded : [];

        setState(() {
          myApplications = data;
          loadingApplications = false;
        });
      } else {
        setState(() {
          myApplications = [];
          loadingApplications = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        myApplications = [];
        loadingApplications = false;
      });
    }
  }

  Future<void> _loadSavedEvents() async {
    final saved = await SavedEventsService.getSavedEvents();
    if (!mounted) return;

    setState(() {
      savedEventIds = saved
          .map((event) => event["id"].toString())
          .toSet();
    });
  }

  Future<void> _toggleSaved(Map<String, dynamic> event) async {
    final updated = await SavedEventsService.toggleSaved(event);
    if (!mounted) return;

    setState(() {
      final id = event["id"].toString();
      if (updated) {
        savedEventIds.add(id);
      } else {
        savedEventIds.remove(id);
      }
    });
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

  // ✅ categories is a LIST, not a string
  final List categories = (e["categories"] ?? []);
  final matchesCategory =
      selectedCategory == "All" || categories.contains(selectedCategory);

  // ✅ use event_type instead of payment_per_day
  final isPaid = e["event_type"] == "paid";

  bool matchesPayment = true;
  if (filterPaid && !filterUnpaid) {
    matchesPayment = isPaid;
  } else if (!filterPaid && filterUnpaid) {
    matchesPayment = !isPaid;
  }

  final computedStatus = e["computed_status"]?.toString();
  final isCompleted = computedStatus == "completed" ||
      _isPastEventDate(e["event_date"]?.toString());

  return matchesSearch && matchesCategory && matchesPayment && !isCompleted;
}).toList();



return RefreshIndicator(
  onRefresh: () async {
    await fetchEvents();
    await fetchMyApplications();
    await _loadSavedEvents();
  },
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // 🔍 Search + Filter
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
            if (selectedFeed == "all")
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

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _feedSegment(
                  label: "All",
                  value: "all",
                  count: filteredEvents.length,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _feedSegment(
                  label: "Confirmed",
                  value: "confirmed",
                  count: _countByStatus("accepted"),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _feedSegment(
                  label: "Pending",
                  value: "pending",
                  count: _countByStatus("pending"),
                ),
              ),
            ],
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          selectedFeed == "confirmed"
              ? "Confirmed Events"
              : selectedFeed == "pending"
                  ? "Pending Events"
                  : "Volunteer Jobs",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),

      const SizedBox(height: 12),

      // 📋 EVENTS LIST
      Expanded(
        child: _buildEventList(filteredEvents),
      ),
    ],
  ),
);
  }

  Widget _buildEventList(List filteredEvents) {
    if (selectedFeed != "all" && loadingApplications) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedFeed == "all") {
      if (filteredEvents.isEmpty) {
        return const Center(child: Text("No events found"));
      }
      return _eventListView(filteredEvents);
    }

    final apps = _filteredApplications();
    if (apps.isEmpty) {
      return Center(
        child: Text(
          selectedFeed == "confirmed"
              ? "No confirmed events"
              : "No pending events",
        ),
      );
    }

    final eventById = {
      for (final event in events)
        event["id"]?.toString(): event,
    };

    final merged = apps.map((app) {
      final eventId = app["event_id"]?.toString();
      return eventById[eventId] ?? app;
    }).toList();

    return _eventListView(merged);
  }

  Widget _eventListView(List list) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final event = list[index];

        final eventId = event["id"]?.toString() ??
            event["event_id"]?.toString();
        final isSaved =
            eventId != null && savedEventIds.contains(eventId);

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewEventScreen(event: event),
              ),
            );
            await _loadSavedEvents();
            await fetchMyApplications();
          },
          child: _eventCard(
            title: event["title"] ?? "",
            location: event["location"] ?? "",
            date: event["event_date"]
                    ?.toString()
                    .split("T")[0] ??
                "",
            slotsLeft: event["volunteers_required"] ?? 0,
            isSaved: isSaved,
            onToggleSaved: () => _toggleSaved(event),
          ),
        );
      },
    );
  }

  List _filteredApplications() {
    return myApplications.where((app) {
      final status = app["status"]?.toString().toLowerCase() ?? "";
      if (selectedFeed == "confirmed" && status != "accepted") {
        return false;
      }
      if (selectedFeed == "pending" && status != "pending") {
        return false;
      }

      if (status != "accepted" &&
          _isPastEventDate(app["event_date"]?.toString())) {
        return false;
      }

      final title = (app["title"] ?? "").toString().toLowerCase();
      final location = (app["location"] ?? "").toString().toLowerCase();
      return title.contains(searchQuery) || location.contains(searchQuery);
    }).toList();
  }

  Widget _feedSegment({
    required String label,
    required String value,
    required int count,
  }) {
    final selected = selectedFeed == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFeed = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E6BE6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countByStatus(String status) {
    return myApplications.where((app) {
      final appStatus = app["status"]?.toString().toLowerCase();
      if (appStatus != status) return false;

      if (status != "accepted" &&
          _isPastEventDate(app["event_date"]?.toString())) {
        return false;
      }

      return true;
    }).length;
  }

  bool _isPastEventDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return false;

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return false;

    final now = DateTime.now();
    final eventDateOnly = DateTime(parsed.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);

    return eventDateOnly.isBefore(today);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatInboxScreen(),
                ),
              );
            },
          ),
        ],
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
  Widget _eventCard({
    required String title,
    required String location,
    required String date,
    required int slotsLeft,
    required bool isSaved,
    required VoidCallback onToggleSaved,
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

          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? const Color(0xFF2E6BE6) : Colors.grey,
            ),
            onPressed: onToggleSaved,
            tooltip: isSaved ? "Remove from saved" : "Save event",
          ),
        ],
      ),
    ),
  );
}
