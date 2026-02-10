import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'volunteer_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'view_event_screen.dart';
import 'volunteer_events_screen.dart';
import '../../config/api_config.dart';
import '../../services/saved_events_service.dart';
import '../../services/token_service.dart';
import '../chat/chat_inbox_screen.dart';
import '../../widgets/robust_image.dart';

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
  String? userName;

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
    _loadProfileName();
  }

  Future<void> _loadProfileName() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data["name"]?.toString();
        });
      }
    } catch (_) {
      // Keep fallback name on error.
    }
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
      savedEventIds = saved.map((event) => event["id"].toString()).toSet();
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
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/events"));

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
      return VolunteerEventsScreen(
        events: events,
        loading: loading,
        myApplications: myApplications,
        onRefresh: () async {
          await fetchEvents();
          await fetchMyApplications();
          await _loadSavedEvents();
        },
      );
    } else if (selectedIndex == 2) {
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

    final upcomingEvent = _getUpcomingEvent();
    final recommended = _getRecommendedEvents();

    return RefreshIndicator(
      onRefresh: () async {
        await fetchEvents();
        await fetchMyApplications();
        await _loadSavedEvents();
        await _loadProfileName();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            "Hi, ${(userName ?? "Volunteer").trim()}!",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Find your next volunteer event",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _upcomingEventCard(upcomingEvent),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recommended for You",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => setState(() => selectedIndex = 1),
                child: const Text("View All"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recommended.isEmpty) const Text("No recommendations available"),
          ...recommended.map(_recommendedCard),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getUpcomingEvent() {
    final upcoming = events
        .where((e) => !_isPastEventDate(e["event_date"]?.toString()))
        .toList();

    upcoming.sort((a, b) {
      final aDate = DateTime.tryParse(a["event_date"]?.toString() ?? "");
      final bDate = DateTime.tryParse(b["event_date"]?.toString() ?? "");
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    if (upcoming.isEmpty) return null;
    return Map<String, dynamic>.from(upcoming.first);
  }

  List<Map<String, dynamic>> _getRecommendedEvents() {
    return events
        .where((e) => !_isPastEventDate(e["event_date"]?.toString()))
        .take(3)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _upcomingEventCard(Map<String, dynamic>? event) {
    if (event == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text("No upcoming events yet"),
      );
    }

    final date = _formatDate(event["event_date"]?.toString());
    final time =
        "${_formatTime(event["start_time"])} - ${_formatTime(event["end_time"])}";

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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFEAF0FF), Color(0xFFF2FFF7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Upcoming Event",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event["title"] ?? "",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(date, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event["location"] ?? "",
                          style: const TextStyle(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(time, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _eventImage(event["banner_url"]?.toString()),
                const SizedBox(height: 12),
                _gradientButton(
                  label: "View Details",
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendedCard(Map<String, dynamic> event) {
    final date = _formatDate(event["event_date"]?.toString());
    final time =
        "${_formatTime(event["start_time"])} - ${_formatTime(event["end_time"])}";
    final rawStatus = _applicationStatusForEvent(event);
    final actionState = _actionState(rawStatus);

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEAF0FF),
              child: const Icon(Icons.volunteer_activism,
                  color: Color(0xFF2E6BE6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event["title"] ?? "",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event["location"] ?? "",
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            actionState.isEnabled
                ? _gradientButton(
                    label: actionState.label,
                    compact: true,
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
                  )
                : _statusPill(actionState.label, actionState.color),
          ],
        ),
      ),
    );
  }

  String? _applicationStatusForEvent(Map<String, dynamic> event) {
    final eventId = event["id"]?.toString();
    if (eventId == null || eventId.isEmpty) return null;

    for (final app in myApplications) {
      final appEventId = app["event_id"]?.toString();
      if (appEventId == eventId) {
        return app["status"]?.toString().toLowerCase();
      }
    }

    return null;
  }

  _ActionState _actionState(String? status) {
    final normalized = status?.toLowerCase() ?? "";
    if (normalized == "pending") {
      return _ActionState("Pending", false, Colors.orange);
    }
    if (normalized == "accepted" || normalized == "approved") {
      return _ActionState("Accepted", false, Colors.green);
    }
    if (normalized == "rejected") {
      return _ActionState("Rejected", false, Colors.red);
    }

    return _ActionState("Apply", true, const Color(0xFF2ECC71));
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventImage(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 92,
        height: 92,
        color: const Color(0xFFEAF0FF),
        child: url == null || url.isEmpty
            ? const Icon(Icons.image, color: Color(0xFF2E6BE6))
            : RobustImage(
                url: url,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: const Color(0xFFEAF0FF),
                  child: const Icon(Icons.image, color: Color(0xFF2E6BE6)),
                ),
              ),
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "";
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return "";
    return "${parsed.day.toString().padLeft(2, "0")} ${_monthName(parsed.month)} ${parsed.year}";
  }

  String _formatTime(dynamic rawTime) {
    final text = rawTime?.toString() ?? "";
    if (text.isEmpty) return "";
    return text.substring(0, 5);
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
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
      for (final event in events) event["id"]?.toString(): event,
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

        final eventId =
            event["id"]?.toString() ?? event["event_id"]?.toString();
        final isSaved = eventId != null && savedEventIds.contains(eventId);

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
            date: event["event_date"]?.toString().split("T")[0] ?? "",
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
            return SafeArea(
              // ✅ FIX 3: prevents zero-height rendering
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
                      onChanged: (v) => setSheetState(() => filterPaid = v!),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text("Unpaid"),
                      value: filterUnpaid,
                      onChanged: (v) => setSheetState(() => filterUnpaid = v!),
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
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
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
                Text(location, style: const TextStyle(color: Colors.grey)),
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

class _ActionState {
  final String label;
  final bool isEnabled;
  final Color color;

  const _ActionState(this.label, this.isEnabled, this.color);
}
