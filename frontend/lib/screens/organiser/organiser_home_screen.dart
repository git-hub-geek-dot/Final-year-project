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
  int _selectedTab = 0; // 0: All, 1: Ongoing, 2: Upcoming, 3: Completed, 4: Draft
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
                    _tabButton('All', 0, count: events.length),
                    const SizedBox(width: 8),
                    _tabButton('Ongoing', 1, count: ongoing.length),
                    const SizedBox(width: 8),
                    _tabButton('Upcoming', 2, count: upcoming.length),
                    const SizedBox(width: 8),
                    _tabButton('Completed', 3, count: completed.length),
                    const SizedBox(width: 8),
                    _tabButton('Draft', 4, count: draft.length),
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
                          _section('All Events', events)
                        else if (_selectedTab == 1)
                          _section('Ongoing Events', ongoing, isCompleted: false)
                        else if (_selectedTab == 2)
                          _section('Upcoming Events', upcoming, isCompleted: false)
                        else if (_selectedTab == 3)
                          _section('Completed Events', completed, isCompleted: true)
                        else
                          _section('Draft Events', draft, isDraft: true),
                      ],
                    ),
                  ),
          ),
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

  Widget _tabButton(String label, int tabIndex, {required int count}) {
    final isActive = _selectedTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tabIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.22) : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
  final statusKey = _eventStatus(event);
  final statusLabel = _statusLabel(statusKey);
  final statusColor = _statusColor(statusKey);
  final statusBg = _statusBg(statusKey);
  final urgency = _urgencyBadge(event, statusKey);
  final progress = _progressData(event);
  final signals = _healthSignals(event, statusKey, progress);
  final isEventCompleted = statusKey == 'completed';
  final isEventDraft = statusKey == 'draft';

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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (urgency != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: urgency['bg'] as Color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            urgency['text'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: urgency['color'] as Color,
                            ),
                          ),
                        ),
                    ],
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
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (progress['ratio'] as double),
                      minHeight: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF22C55E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progress['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (signals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: signals
                        .map(
                          (signal) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4D6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFACC15).withOpacity(0.6),
                              ),
                            ),
                            child: Text(
                              signal,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF854D0E),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (isEventCompleted) ...[
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
          if (isMine && !isEventCompleted && !isEventDraft)
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

String _eventStatus(Map event) =>
    (event['computed_status'] ?? event['status'] ?? 'upcoming')
        .toString()
        .toLowerCase();

String _statusLabel(String status) {
  switch (status) {
    case 'ongoing':
      return 'Ongoing';
    case 'upcoming':
      return 'Upcoming';
    case 'completed':
      return 'Completed';
    case 'draft':
      return 'Draft';
    default:
      return 'Upcoming';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'ongoing':
      return const Color(0xFF15803D);
    case 'upcoming':
      return const Color(0xFF1D4ED8);
    case 'completed':
      return const Color(0xFF6D28D9);
    case 'draft':
      return Colors.grey.shade700;
    default:
      return Colors.black87;
  }
}

Color _statusBg(String status) {
  switch (status) {
    case 'ongoing':
      return const Color(0xFFDCFCE7);
    case 'upcoming':
      return const Color(0xFFDBEAFE);
    case 'completed':
      return const Color(0xFFEDE9FE);
    case 'draft':
      return Colors.grey.shade200;
    default:
      return Colors.grey.shade200;
  }
}

DateTime? _parseEventDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int? _readIntFromKeys(Map event, List<String> keys) {
  for (final key in keys) {
    final value = event[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

Map<String, dynamic>? _urgencyBadge(Map event, String status) {
  final now = DateTime.now();
  final eventDate = _parseEventDate(event['event_date']);
  final deadline = _parseEventDate(event['application_deadline']);

  if (status == 'draft') {
    return {
      'text': 'Not published',
      'color': Colors.grey.shade700,
      'bg': Colors.grey.shade200,
    };
  }

  if (status == 'upcoming' && eventDate != null) {
    final days = eventDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 0) {
      return {
        'text': 'Starts today',
        'color': const Color(0xFFB45309),
        'bg': const Color(0xFFFEF3C7),
      };
    }
    if (days <= 2) {
      return {
        'text': 'Starts in ${days}d',
        'color': const Color(0xFFB45309),
        'bg': const Color(0xFFFEF3C7),
      };
    }
  }

  if (status == 'upcoming' && deadline != null) {
    final days = deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 1) {
      return {
        'text': days < 0 ? 'Deadline passed' : 'Deadline soon',
        'color': const Color(0xFFB91C1C),
        'bg': const Color(0xFFFEE2E2),
      };
    }
  }

  return null;
}

Map<String, dynamic>? _progressData(Map event) {
  final requiredVolunteers = _readIntFromKeys(event, ['volunteers_required']) ?? 0;
  if (requiredVolunteers <= 0) return null;

  final accepted = _readIntFromKeys(
    event,
    ['accepted_count', 'approved_count', 'slots_filled', 'filled_slots'],
  );
  final applicants = _readIntFromKeys(
    event,
    ['applications_count', 'applicants_count', 'applied_count', 'total_applications'],
  );

  if (accepted == null && applicants == null) return null;

  final raw = accepted ?? applicants ?? 0;
  final ratio = (raw / requiredVolunteers).clamp(0.0, 1.0).toDouble();
  final label = accepted != null
      ? '$accepted / $requiredVolunteers volunteers filled'
      : '$raw / $requiredVolunteers applicants';

  return {
    'ratio': ratio,
    'label': label,
    'accepted': accepted,
    'applicants': applicants,
    'required': requiredVolunteers,
  };
}

List<String> _healthSignals(
  Map event,
  String status,
  Map<String, dynamic>? progress,
) {
  final signals = <String>[];

  if (status == 'draft') {
    signals.add('Draft not visible to volunteers');
    return signals;
  }

  final deadline = _parseEventDate(event['application_deadline']);
  if (status == 'upcoming' && deadline != null && deadline.isBefore(DateTime.now())) {
    signals.add('Application deadline passed');
  }

  final applicants = progress?['applicants'] as int?;
  final accepted = progress?['accepted'] as int?;
  final required = progress?['required'] as int?;

  if (status == 'upcoming' && applicants != null && applicants == 0) {
    signals.add('No applications yet');
  }

  if (status == 'ongoing' &&
      required != null &&
      required > 0 &&
      accepted != null &&
      accepted < required) {
    signals.add('Understaffed by ${required - accepted}');
  }

  return signals;
}
