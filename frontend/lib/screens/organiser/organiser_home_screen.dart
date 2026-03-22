import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/event_service.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';
import '../../services/notification_api_service.dart';
import '../../utils/ist_date_time.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../../localization/localization_extensions.dart';
import 'create_event_screen.dart';
import 'get_verified_screen.dart';
import 'review_application_screen.dart';
import 'event_details_screen.dart';
import '../chat/chat_inbox_screen.dart';
import '../notifications/notifications_screen.dart';

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
  int _selectedTab =
      0; // 0: All, 1: Ongoing, 2: Upcoming, 3: Completed, 4: Draft, 5: Cancelled
  String? loadError;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadCachedEvents();
    loadEvents();
    _loadUnreadCount();
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
      await _loadUnreadCount();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheEventsKey, jsonEncode(data));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = context.tr(
          "Failed to load events. Pull to refresh or tap Retry.",
        );
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationApiService.fetchUnreadCount();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = count;
      });
    } catch (_) {
      // Ignore unread count errors
    }
  }

  Future<void> _openOrganiserVerificationFlow() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganiserGetVerifiedScreen(),
      ),
    );
  }

  Future<bool> _ensureVerifiedOrganiser() async {
    final status = (await VerificationService.getStatus())?.toLowerCase();

    if (status == "approved") {
      return true;
    }

    if (!mounted) return false;

    String message;
    String actionText;
    VoidCallback? action;

    switch (status) {
      case "pending":
        message = context.tr(
          "Your verification is under review. You can create events after approval.",
        );
        actionText = context.tr("OK");
        action = () => Navigator.pop(context);
        break;
      case "rejected":
        message = context.tr(
          "Your verification was rejected. Please submit verification again to create events.",
        );
        actionText = context.tr("Get Verified");
        action = () async {
          Navigator.pop(context);
          await _openOrganiserVerificationFlow();
        };
        break;
      case "not_requested":
        message = context.tr("You need to be verified before creating events.");
        actionText = context.tr("Get Verified");
        action = () async {
          Navigator.pop(context);
          await _openOrganiserVerificationFlow();
        };
        break;
      default:
        message = context
            .tr("Unable to verify your account right now. Please try again.");
        actionText = context.tr("OK");
        action = () => Navigator.pop(context);
        break;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Verification Required")),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr("Cancel")),
          ),
          TextButton(
            onPressed: action,
            child: Text(actionText),
          ),
        ],
      ),
    );
    return false;
  }

  String _status(Map e) {
    final status = (e['computed_status'] ?? e['status'] ?? 'upcoming')
        .toString()
        .toLowerCase();
    if (status == 'closed') return 'cancelled';
    if (status == 'deleted' || status == 'deleted_by_admin') {
      return 'deleted_by_admin';
    }
    return status;
  }

  List getUpcomingEvents() =>
      events.where((e) => _status(e) == 'upcoming').toList();

  List getOngoingEvents() =>
      events.where((e) => _status(e) == 'ongoing').toList();

  List getCompletedEvents() =>
      events.where((e) => _status(e) == 'completed').toList();

  List getDraftEvents() => events.where((e) => _status(e) == 'draft').toList();

  List getCancelledEvents() =>
      events.where((e) => _status(e) == 'cancelled').toList();

  List getDeletedEvents() =>
      events.where((e) => _status(e) == 'deleted_by_admin').toList();

  @override
  Widget build(BuildContext context) {
    final upcoming = getUpcomingEvents();
    final ongoing = getOngoingEvents();
    final completed = getCompletedEvents();
    final draft = getDraftEvents();
    final cancelled = getCancelledEvents();

    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 122,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                        await _loadUnreadCount();
                      },
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications,
                            color: Colors.white,
                          ),
                          if (_unreadNotifications > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                ),
                                child: Text(
                                  _unreadNotifications > 99
                                      ? context.tr("99+")
                                      : _unreadNotifications.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: () async {
                final canCreate = await _ensureVerifiedOrganiser();
                if (!canCreate || !mounted) return;

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
                child: Center(
                  child: Text(
                    context.tr('Create Event'),
                    style: const TextStyle(
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabButton(context.tr('All'), 0, count: events.length),
                    const SizedBox(width: 8),
                    _tabButton(context.tr('Ongoing'), 1, count: ongoing.length),
                    const SizedBox(width: 8),
                    _tabButton(context.tr('Upcoming'), 2,
                        count: upcoming.length),
                    const SizedBox(width: 8),
                    _tabButton(context.tr('Completed'), 3,
                        count: completed.length),
                    const SizedBox(width: 8),
                    _tabButton(context.tr('Draft'), 4, count: draft.length),
                    const SizedBox(width: 8),
                    _tabButton(context.tr('Cancelled'), 5,
                        count: cancelled.length),
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
                                border:
                                    Border.all(color: const Color(0xFFFFD7D7)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      loadError!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: loadEvents,
                                    child: Text(context.tr("Retry")),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_selectedTab == 0)
                          _section(context.tr('All Events'), events)
                        else if (_selectedTab == 1)
                          _section(context.tr('Ongoing Events'), ongoing,
                              isCompleted: false)
                        else if (_selectedTab == 2)
                          _section(context.tr('Upcoming Events'), upcoming,
                              isCompleted: false)
                        else if (_selectedTab == 3)
                          _section(context.tr('Completed Events'), completed,
                              isCompleted: true)
                        else if (_selectedTab == 4)
                          _section(context.tr('Draft Events'), draft,
                              isDraft: true),
                        if (_selectedTab == 5)
                          _section(context.tr('Cancelled Events'), cancelled),
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
            context.tr(
              'No {title}',
              args: {"title": title},
            ),
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
  final isEventCancelled = statusKey == 'cancelled';
  final isEventDeleted = statusKey == 'deleted_by_admin';
  final progressLabel = progress == null
      ? null
      : progress['accepted'] != null
          ? context.tr(
              'Approved: {accepted} / {required}',
              args: {
                'accepted': (progress['accepted'] ?? 0).toString(),
                'required': (progress['required'] ?? 0).toString(),
              },
            )
          : context.tr(
              'Applicants: {raw} / {required}',
              args: {
                'raw': (progress['applicants'] ?? 0).toString(),
                'required': (progress['required'] ?? 0).toString(),
              },
            );

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
                          context.tr(statusLabel),
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
                            context.tr(
                              urgency['text'] as String,
                              args: (urgency['args'] as Map<String, String>?) ??
                                  const {},
                            ),
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
                      context.tr(
                        'Organiser: {name}',
                        args: {"name": event['organiser_name'].toString()},
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                Text(
                  event['title'] ?? context.tr('Untitled'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Location: {location}',
                    args: {
                      "location":
                          (event['location'] ?? context.tr('N/A')).toString()
                    },
                  ),
                ),
                Text(
                  context.tr(
                    'Date: {date}',
                    args: {"date": _formatDateRange(event)},
                  ),
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
                    progressLabel ?? '',
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
                              context.tr(
                                signal['key'] as String,
                                args:
                                    (signal['args'] as Map<String, String>?) ??
                                        const {},
                              ),
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
                            : context.tr('No ratings yet'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isMine &&
              !isEventCompleted &&
              !isEventDraft &&
              !isEventCancelled &&
              !isEventDeleted)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReviewApplicationsScreen(eventId: event['id']),
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
                child: Text(
                  context.tr('Review'),
                  style: const TextStyle(
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

String _eventStatus(Map event) {
  final status = (event['computed_status'] ?? event['status'] ?? 'upcoming')
      .toString()
      .toLowerCase();
  if (status == 'closed') return 'cancelled';
  if (status == 'deleted' || status == 'deleted_by_admin') {
    return 'deleted_by_admin';
  }
  return status;
}

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
    case 'cancelled':
      return 'Cancelled';
    case 'deleted_by_admin':
      return 'Removed by admin';
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
    case 'cancelled':
      return const Color(0xFFDC2626);
    case 'deleted_by_admin':
      return const Color(0xFF6B7280);
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
    case 'cancelled':
      return const Color(0xFFFEE2E2);
    case 'deleted_by_admin':
      return const Color(0xFFF3F4F6);
    default:
      return Colors.grey.shade200;
  }
}

DateTime? _parseEventDate(dynamic value) {
  if (value == null) return null;
  return IstDateTime.tryParse(value);
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
  final now = IstDateTime.now();
  final eventDate = _parseEventDate(event['event_date']);
  final deadline = _parseEventDate(event['application_deadline']);

  if (status == 'draft') {
    return {
      'text': 'Not published',
      'color': Colors.grey.shade700,
      'bg': Colors.grey.shade200,
    };
  }

  if (status == 'cancelled') {
    return {
      'text': 'Cancelled by organiser',
      'color': const Color(0xFFB91C1C),
      'bg': const Color(0xFFFEE2E2),
    };
  }

  if (status == 'deleted_by_admin') {
    return {
      'text': 'Removed by admin',
      'color': const Color(0xFF4B5563),
      'bg': const Color(0xFFF3F4F6),
    };
  }

  if (status == 'upcoming' && eventDate != null) {
    final days =
        eventDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 0) {
      return {
        'text': 'Starts today',
        'color': const Color(0xFFB45309),
        'bg': const Color(0xFFFEF3C7),
      };
    }
    if (days <= 2) {
      return {
        'text': 'Starts in {days}d',
        'args': {'days': days.toString()},
        'color': const Color(0xFFB45309),
        'bg': const Color(0xFFFEF3C7),
      };
    }
  }

  if (status == 'upcoming' && deadline != null) {
    final days =
        deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
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
  final requiredVolunteers =
      _readIntFromKeys(event, ['volunteers_required']) ?? 0;
  if (requiredVolunteers <= 0) return null;

  final accepted = _readIntFromKeys(
    event,
    ['accepted_count', 'approved_count', 'slots_filled', 'filled_slots'],
  );
  final applicants = _readIntFromKeys(
    event,
    [
      'applications_count',
      'applicants_count',
      'applied_count',
      'total_applications'
    ],
  );

  if (accepted == null && applicants == null) return null;

  final raw = accepted ?? applicants ?? 0;
  final ratio = (raw / requiredVolunteers).clamp(0.0, 1.0).toDouble();
  final label = accepted != null
      ? 'Approved: $accepted / $requiredVolunteers'
      : 'Applicants: $raw / $requiredVolunteers';

  return {
    'ratio': ratio,
    'label': label,
    'accepted': accepted,
    'applicants': applicants,
    'required': requiredVolunteers,
  };
}

List<Map<String, dynamic>> _healthSignals(
  Map event,
  String status,
  Map<String, dynamic>? progress,
) {
  final signals = <Map<String, dynamic>>[];

  if (status == 'draft') {
    signals.add({'key': 'Draft not visible to volunteers'});
    return signals;
  }

  final deadline = _parseEventDate(event['application_deadline']);
  if (status == 'upcoming' &&
      deadline != null &&
      deadline.isBefore(IstDateTime.now())) {
    signals.add({'key': 'Application deadline passed'});
  }

  final applicants = progress?['applicants'] as int?;
  final accepted = progress?['accepted'] as int?;
  final required = progress?['required'] as int?;

  if (status == 'upcoming' && applicants != null && applicants == 0) {
    signals.add({'key': 'No applications yet'});
  }

  if (status == 'ongoing' &&
      required != null &&
      required > 0 &&
      accepted != null &&
      accepted < required) {
    signals.add({
      'key': 'Understaffed by {count}',
      'args': {'count': (required - accepted).toString()},
    });
  }

  return signals;
}

String _formatDateRange(Map event) {
  final startDateRaw = event['event_date']?.toString();
  final endDateRaw = event['end_date']?.toString();

  if (startDateRaw == null || startDateRaw.isEmpty) return 'N/A';

  final startParsed = IstDateTime.tryParse(startDateRaw);
  if (startParsed == null) return 'N/A';
  final startDate = IstDateTime.formatDate(startParsed);

  // If no end date, show single date
  if (endDateRaw == null || endDateRaw.isEmpty) {
    return startDate;
  }

  final endParsed = IstDateTime.tryParse(endDateRaw);
  if (endParsed == null) return startDate;
  final endDate = IstDateTime.formatDate(endParsed);

  // If dates are the same, show single date
  if (startDate == endDate) {
    return startDate;
  }

  // Show date range for multi-day events
  return '$startDate to $endDate';
}
