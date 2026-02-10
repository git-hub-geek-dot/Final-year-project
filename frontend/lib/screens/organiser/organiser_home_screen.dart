import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/event_service.dart';
import '../../services/token_service.dart';
import '../../widgets/organiser_bottom_nav.dart';
import 'create_event_screen.dart';
import 'review_application_screen.dart';
import 'event_details_screen.dart';
import '../chat/chat_inbox_screen.dart';

class OrganiserHomeScreen extends StatefulWidget {
  const OrganiserHomeScreen({super.key});

  @override
  State<OrganiserHomeScreen> createState() => _OrganiserHomeScreenState();
}

class _OrganiserHomeScreenState extends State<OrganiserHomeScreen> {
  static const String _cacheEventsKey = "cached_organiser_events";

  bool loading = true;
  List events = [];
  int? userId;
  int _selectedTab = 0; // 0: Ongoing, 1: Upcoming, 2: Completed, 3: Draft
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadCachedEvents();
    loadEvents();
  }

  Future<void> _loadCachedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheEventsKey);
    if (cached == null || cached.isEmpty) return;

    try {
      final decoded = jsonDecode(cached);
      if (decoded is List && mounted) {
        setState(() {
          events = decoded;
          loading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> loadEvents() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }

    try {
      final id = await TokenService.getUserId();
      final data = await EventService.fetchMyEvents();
      if (!mounted) return;
      setState(() {
        userId = id;
        events = data;
        loading = false;
        loadError = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheEventsKey, jsonEncode(data));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = "Failed to load events. Pull to refresh or tap Retry.";
      });
    }
  }

  String _status(Map e) =>
      (e['computed_status'] ?? e['status'] ?? 'upcoming').toString();

  List getUpcomingEvents() =>
      events.where((e) => _status(e) == 'upcoming').toList();

  List getOngoingEvents() =>
      events.where((e) => _status(e) == 'ongoing').toList();

  List getCompletedEvents() =>
      events.where((e) => _status(e) == 'completed').toList();

  List getDraftEvents() => events.where((e) => _status(e) == 'draft').toList();

  List getDeletedEvents() =>
      events.where((e) => _status(e) == 'deleted_by_admin').toList();

  @override
  Widget build(BuildContext context) {
    final upcoming = getUpcomingEvents();
    final ongoing = getOngoingEvents();
    final completed = getCompletedEvents();
    final draft = getDraftEvents();

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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Volunteerx',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatInboxScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications screen coming soon.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
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
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                ).then((_) => loadEvents());
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
                    'Create Event',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _eventScopeButton('Events', true, () {}),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabButton('Ongoing', 0),
                    const SizedBox(width: 8),
                    _tabButton('Upcoming', 1),
                    const SizedBox(width: 8),
                    _tabButton('Completed', 2),
                    const SizedBox(width: 8),
                    _tabButton('Draft', 3),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: loadEvents,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        if (loadError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4F4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFD7D7)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      loadError!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: loadEvents,
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_selectedTab == 0)
                          _section('Ongoing Events', ongoing, isCompleted: false)
                        else if (_selectedTab == 1)
                          _section('Upcoming Events', upcoming, isCompleted: false)
                        else if (_selectedTab == 2)
                          _section('Completed Events', completed, isCompleted: true)
                        else
                          _section('Draft Events', draft, isDraft: true),
                      ],
                    ),
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
                  StatItem(events.length.toString(), 'Total'),
                  StatItem(draft.length.toString(), 'Draft'),
                  StatItem(ongoing.length.toString(), 'Ongoing'),
                  StatItem(upcoming.length.toString(), 'Upcoming'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
      bottomNavigationBar: const OrganiserBottomNav(currentIndex: 0),
    );
  }

  Widget _section(
    String title,
    List list, {
    bool isCompleted = false,
    bool isDraft = false,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No $title',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...list.map(
          (event) => eventCard(
            context,
            event,
            loadEvents,
            _isMyEvent(event),
            isCompleted: isCompleted,
            isDraft: isDraft,
          ),
        ),
      ],
    );
  }

  Widget _tabButton(String label, int tabIndex) {
    final isActive = _selectedTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tabIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _eventScopeButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3B82F6) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _isMyEvent(Map event) {
    if (userId == null) return false;
    return event['organiser_id'] == userId;
  }
}

Widget eventCard(
  BuildContext context,
  Map event,
  VoidCallback onRefresh,
  bool isMine, {
  bool isCompleted = false,
  bool isDraft = false,
}) {
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
        border: Border.all(
          color: isMine ? const Color(0xFF22C55E) : Colors.grey.shade300,
          width: isMine ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMine)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFDCFCE7)
                          : isDraft
                              ? Colors.grey.shade200
                              : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isCompleted
                          ? 'Completed'
                          : isDraft
                              ? 'Draft'
                              : 'My Event',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFF16A34A)
                            : isDraft
                                ? Colors.grey.shade700
                                : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                if (!isMine && event['organiser_name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Organiser: ${event['organiser_name']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                Text(
                  event['title'] ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Location: ${event['location'] ?? 'N/A'}'),
                Text(
                  'Date: ${event['event_date'] == null ? 'N/A' : event['event_date'].toString().split('T')[0]}',
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        event['rating'] != null
                            ? "${event['rating']} (${event['review_count'] ?? 0})"
                            : 'No ratings yet',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isMine && !isCompleted && !isDraft)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewApplicationsScreen(eventId: event['id']),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
