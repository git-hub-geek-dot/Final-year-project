import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'volunteer_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'view_event_screen.dart';
import 'volunteer_events_screen.dart';
import '../../config/api_config.dart';
import '../../config/goa_cities.dart';
import '../../services/saved_events_service.dart';
import '../../services/token_service.dart';
import '../../services/notification_api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/ist_date_time.dart';
import '../../localization/localization_extensions.dart';
import '../chat/chat_inbox_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/robust_image.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  int selectedIndex = 0;
  String eventsTab = "all"; // all | upcoming | ongoing | past
  List events = [];
  List myApplications = [];
  bool loading = true;
  bool loadingApplications = true;
  Set<String> savedEventIds = {};
  String? userName;
  String? userCity;
  int _unreadNotifications = 0;

  final GlobalKey _introKey = GlobalKey();
  final GlobalKey _upcomingHeaderKey = GlobalKey();
  final GlobalKey _recommendedHeaderKey = GlobalKey();
  final GlobalKey _upcomingCardKey = GlobalKey();
  final GlobalKey _recommendedCardKey = GlobalKey();

  double? _introHeight;
  double? _upcomingHeaderHeight;
  double? _recommendedHeaderHeight;
  double? _upcomingCardHeight;
  double? _recommendedCardHeight;

  String selectedFeed = "all"; // all | confirmed | pending
  String selectedTimeline = "upcoming"; // upcoming | ongoing

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
    _loadUnreadCount();
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
          userCity = data["city"]?.toString();
        });
      }
    } catch (_) {
      // Keep fallback name on error.
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
      debugPrint("MY APPLICATIONS: ${response.body}");

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
        initialTab: eventsTab,
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

    final pendingRatings = _getPendingRatingApplications();
    final upcomingAccepted = _getUpcomingAcceptedEvents();
    final ongoingAccepted = _getOngoingAcceptedEvents();
    final isOngoing = selectedTimeline == "ongoing";
    final primaryEvents = isOngoing ? ongoingAccepted : upcomingAccepted;
    final recommended = _getRecommendedEvents();
    _scheduleMeasurements();

    final media = MediaQuery.of(context);
    const listPadding = 16.0 + 24.0;
    const listSpacing = 16.0 + 8.0 + 16.0 + 8.0;
    final fixedHeights = (_introHeight ?? 0) +
        (_upcomingHeaderHeight ?? 0) +
        (_recommendedHeaderHeight ?? 0) +
        listPadding +
        listSpacing;
    final viewportHeight = media.size.height -
        media.padding.top -
        media.padding.bottom -
        kBottomNavigationBarHeight;
    var available = viewportHeight - fixedHeights;
    if (available < 0) {
      available = 0;
    }

    final upcomingCardHeight =
        _upcomingCardHeight ?? _recommendedCardHeight ?? 110;
    final recommendedCardHeight =
        _recommendedCardHeight ?? _upcomingCardHeight ?? 110;

    final primaryShown =
        primaryEvents.isEmpty ? 1 : primaryEvents.length.clamp(1, 2);
    available -= primaryShown * upcomingCardHeight;
    if (available < 0) {
      available = 0;
    }

    final recommendedShown = recommended.isEmpty
        ? 0
        : (() {
            final computed = (available / recommendedCardHeight)
                .floor()
                .clamp(1, recommended.length);
            final minShown = 3;
            final maxShownWhenNoPrimary = 5;
            final base = primaryEvents.isEmpty
                ? computed.clamp(minShown, maxShownWhenNoPrimary)
                : computed < minShown
                    ? minShown
                    : computed;
            return base.clamp(1, recommended.length);
          })();
    final primaryPreview = primaryEvents.take(primaryShown).toList();
    final recommendedPreview = recommended.take(recommendedShown).toList();
    final showUpcomingViewAll = primaryEvents.length > primaryShown;
    final showRecommendedViewAll = recommended.length > recommendedShown;

    return RefreshIndicator(
      onRefresh: () async {
        await fetchEvents();
        await fetchMyApplications();
        await _loadSavedEvents();
        await _loadProfileName();
        await _loadUnreadCount();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Column(
            key: _introKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  "Hi, {name}!",
                  args: {
                    "name": (userName ?? context.tr("Volunteer")).trim(),
                  },
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr("Find your next volunteer event"),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          if (pendingRatings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _pendingRatingReminderCard(pendingRatings),
          ],
          const SizedBox(height: 16),
          Container(
            key: _upcomingHeaderKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isOngoing
                          ? context.tr("My Ongoing Events")
                          : context.tr("My Upcoming Events"),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      _timelineSegment(
                        label: context.tr("Upcoming"),
                        value: "upcoming",
                        count: upcomingAccepted.length,
                      ),
                      _timelineSegment(
                        label: context.tr("Ongoing"),
                        value: "ongoing",
                        count: ongoingAccepted.length,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (primaryEvents.isEmpty)
            _upcomingEventCard(
              null,
              key: _upcomingCardKey,
              emptyLabel: isOngoing
                  ? context.tr("No ongoing events yet")
                  : context.tr("No upcoming events yet"),
            ),
          ...primaryPreview.asMap().entries.map(
                (entry) => _upcomingEventCard(
                  entry.value,
                  key: entry.key == 0 ? _upcomingCardKey : null,
                ),
              ),
          if (showUpcomingViewAll)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  eventsTab = isOngoing ? "ongoing" : "upcoming";
                  selectedIndex = 1;
                }),
                child: Text(context.tr("View All")),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            key: _recommendedHeaderKey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr("Recommended for You"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (recommended.isEmpty)
            Text(context.tr("No recommendations available")),
          ...recommendedPreview.asMap().entries.map(
                (entry) => _recommendedCard(
                  entry.value,
                  key: entry.key == 0 ? _recommendedCardKey : null,
                ),
              ),
          if (showRecommendedViewAll)
            Align(
              alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => selectedIndex = 1),
                  child: Text(context.tr("View All")),
                ),
              ),
        ],
      ),
    );
  }

  void _scheduleMeasurements() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateMeasuredHeight(_introKey, _introHeight, (v) => _introHeight = v);
      _updateMeasuredHeight(
        _upcomingHeaderKey,
        _upcomingHeaderHeight,
        (v) => _upcomingHeaderHeight = v,
      );
      _updateMeasuredHeight(
        _recommendedHeaderKey,
        _recommendedHeaderHeight,
        (v) => _recommendedHeaderHeight = v,
      );
      _updateMeasuredHeight(
        _upcomingCardKey,
        _upcomingCardHeight,
        (v) => _upcomingCardHeight = v,
      );
      _updateMeasuredHeight(
        _recommendedCardKey,
        _recommendedCardHeight,
        (v) => _recommendedCardHeight = v,
      );
    });
  }

  void _updateMeasuredHeight(
    GlobalKey key,
    double? current,
    void Function(double) assign,
  ) {
    final context = key.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final next = box.size.height;
    if (next <= 0) return;
    if (current == null || (current - next).abs() > 0.5) {
      setState(() {
        assign(next);
      });
    }
  }

  List<Map<String, dynamic>> _getUpcomingAcceptedEvents() {
    final eventById = {
      for (final event in events) event["id"]?.toString(): event,
    };

    final upcoming = myApplications
        .where((app) {
          final status = app["status"]?.toString().toLowerCase() ?? "";
          return status == "accepted" || status == "approved";
        })
        .map((app) {
          final eventId =
              app["event_id"]?.toString() ?? app["event"]?["id"]?.toString();
          final base = eventById[eventId] ?? app;
          return Map<String, dynamic>.from(base);
        })
        .where(_isUpcomingEvent)
        .toList();

    upcoming.sort((a, b) {
      final aDate = IstDateTime.tryParse(a["event_date"]?.toString() ?? "");
      final bDate = IstDateTime.tryParse(b["event_date"]?.toString() ?? "");
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    return upcoming;
  }

  List<Map<String, dynamic>> _getOngoingAcceptedEvents() {
    final eventById = {
      for (final event in events) event["id"]?.toString(): event,
    };

    final ongoing = myApplications
        .where((app) {
          final status = app["status"]?.toString().toLowerCase() ?? "";
          return status == "accepted" || status == "approved";
        })
        .map((app) {
          final eventId =
              app["event_id"]?.toString() ?? app["event"]?["id"]?.toString();
          final base = eventById[eventId] ?? app;
          return Map<String, dynamic>.from(base);
        })
        .where(_isOngoingEvent)
        .toList();

    ongoing.sort((a, b) {
      final aDate = IstDateTime.tryParse(a["event_date"]?.toString() ?? "");
      final bDate = IstDateTime.tryParse(b["event_date"]?.toString() ?? "");
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    return ongoing;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == "true" || text == "1" || text == "t" || text == "yes";
  }

  String _normalizedAttendanceStatus(dynamic value) {
    final text = (value ?? "").toString().trim().toLowerCase();
    if (text == "present" || text == "absent") return text;
    return "unmarked";
  }

  bool _isEventCompletedForRating(Map<String, dynamic> app) {
    if (_asBool(app["event_completed"])) return true;

    final status = (app["event_status"] ?? "").toString().toLowerCase();
    if (status == "completed") return true;
    if (status == "draft" || status == "deleted") return false;

    final startDate = _parseEventDate(app["event_date"]?.toString());
    if (startDate == null) return false;
    final endDate = _parseEventDate(app["end_date"]?.toString()) ?? startDate;
    final endTime = app["end_time"]?.toString() ?? "";
    final endDateTime = endTime.trim().isEmpty
        ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)
        : _dateWithTime(endDate, endTime);
    return IstDateTime.now().isAfter(endDateTime);
  }

  List<Map<String, dynamic>> _getPendingRatingApplications() {
    final list = myApplications
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((app) {
      final status = (app["status"] ?? "").toString().toLowerCase();
      final isEligibleStatus =
          status == "approved" || status == "accepted" || status == "completed";
      if (!isEligibleStatus) return false;

      if (_normalizedAttendanceStatus(app["attendance_status"]) == "absent") {
        return false;
      }

      if (_asBool(app["has_rated"])) return false;

      final organiserId = app["organiser_id"];
      if (organiserId == null) return false;

      return _isEventCompletedForRating(app);
    }).toList();

    list.sort((a, b) {
      final aDate = _parseEventDate(a["event_date"]?.toString());
      final bDate = _parseEventDate(b["event_date"]?.toString());
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return list;
  }

  Future<void> _openPendingRatingEvent(Map<String, dynamic> app) async {
    final rawId = app["event_id"];
    final eventId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "");

    if (eventId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Event details not available"))),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final event = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewEventScreen(event: event),
          ),
        );

        await fetchMyApplications();
        await _loadSavedEvents();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to open event details"))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to open event details"))),
      );
    }
  }

  Widget _pendingRatingReminderCard(List<Map<String, dynamic>> pendingRatings) {
    final count = pendingRatings.length;
    final firstTitle =
        (pendingRatings.first["title"] ?? context.tr("event")).toString();
    final subtitle = count == 1
        ? context.tr(
            "Share your feedback for {event}.",
            args: {"event": firstTitle},
          )
        : context.tr(
            "{count} completed events are waiting for your rating.",
            args: {"count": count.toString()},
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C26B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rate_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Pending Rating Reminder"),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C2D12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7C2D12),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openPendingRatingEvent(pendingRatings.first),
            child: Text(context.tr("Rate now")),
          ),
        ],
      ),
    );
  }

  DateTime? _parseEventDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return null;
    return IstDateTime.tryParse(rawDate);
  }

  DateTime _dateWithTime(DateTime date, String? rawTime) {
    final text = rawTime?.toString() ?? "";
    if (text.isEmpty) {
      return DateTime(date.year, date.month, date.day);
    }

    final parts = text.split(":");
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  bool _isUpcomingEvent(Map<String, dynamic> event) {
    final startDate = _parseEventDate(event["event_date"]?.toString());
    if (startDate == null) return false;
    final startDateTime =
        _dateWithTime(startDate, event["start_time"]?.toString());
    final now = IstDateTime.now();
    return startDateTime.isAfter(now);
  }

  bool _isOngoingEvent(Map<String, dynamic> event) {
    final startDate = _parseEventDate(event["event_date"]?.toString());
    if (startDate == null) return false;
    final endDate = _parseEventDate(event["end_date"]?.toString()) ?? startDate;
    final startDateTime =
        _dateWithTime(startDate, event["start_time"]?.toString());
    var endDateTime = _dateWithTime(endDate, event["end_time"]?.toString());
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = startDateTime;
    }
    final now = IstDateTime.now();
    return !now.isBefore(startDateTime) && !now.isAfter(endDateTime);
  }

  List<Map<String, dynamic>> _getRecommendedEvents() {
    final statusByEventId = <String, String>{
      for (final app in myApplications)
        (app["event_id"]?.toString() ?? app["event"]?["id"]?.toString() ?? ""):
            (app["status"]?.toString().toLowerCase() ?? ""),
    };

    // Extract categories from events user has applied to
    final Set<String> interestedCategories = {};
    for (final app in myApplications) {
      final categories = app["categories"];
      if (categories is List) {
        for (final cat in categories) {
          if (cat != null) {
            interestedCategories.add(cat.toString().toLowerCase().trim());
          }
        }
      }
    }

    final upcoming = events
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((event) {
          final startDate = _parseEventDate(event["event_date"]?.toString());
          if (startDate == null) {
            return false;
          }
          if (_hasEventEndedForRecommendation(event)) {
            return false;
          }
          final status = statusByEventId[event["id"]?.toString() ?? ""] ?? "";
          return status.isEmpty; // only unapplied events
        })
        .toList();

    // Priority sorting: Categories > Distance > Date
    if (interestedCategories.isNotEmpty) {
      // User has applied to events, prioritize by category match
      upcoming.sort((a, b) {
        // Check if events match user's interested categories
        final aCategories =
            a["categories"] is List ? a["categories"] as List : [];
        final bCategories =
            b["categories"] is List ? b["categories"] as List : [];

        final aHasMatch = aCategories.any((cat) => interestedCategories
            .contains(cat?.toString().toLowerCase().trim() ?? ""));
        final bHasMatch = bCategories.any((cat) => interestedCategories
            .contains(cat?.toString().toLowerCase().trim() ?? ""));

        // Category match comes first
        if (aHasMatch && !bHasMatch) return -1;
        if (!aHasMatch && bHasMatch) return 1;

        // If both match or both don't match, sort by distance
        if (userCity != null &&
            userCity!.isNotEmpty &&
            GoaCities.isKnownCity(userCity!)) {
          final aLocation = a["location"]?.toString() ?? "";
          final bLocation = b["location"]?.toString() ?? "";

          final aDistance = GoaCities.calculateDistance(userCity!, aLocation);
          final bDistance = GoaCities.calculateDistance(userCity!, bLocation);

          final distanceCompare = aDistance.compareTo(bDistance);
          if (distanceCompare != 0) return distanceCompare;
        }

        // If same category match and distance, sort by date
        final aDate = IstDateTime.tryParse(a["event_date"]?.toString() ?? "");
        final bDate = IstDateTime.tryParse(b["event_date"]?.toString() ?? "");
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
    } else {
      // No applications yet, fallback to date-based sorting
      upcoming.sort((a, b) {
        final aDate = IstDateTime.tryParse(a["event_date"]?.toString() ?? "");
        final bDate = IstDateTime.tryParse(b["event_date"]?.toString() ?? "");
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
    }

    return upcoming;
  }

  Widget _upcomingEventCard(
    Map<String, dynamic>? event, {
    Key? key,
    String? emptyLabel,
  }) {
    if (event == null) {
      final resolvedLabel =
          emptyLabel ?? context.tr("No upcoming events yet");
      return Container(
        key: key,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(resolvedLabel),
      );
    }

    final date = _formatDateRange(event);
    final time =
        "${_formatTime(event["start_time"])} - ${_formatTime(event["end_time"])}";
    final progressLabel = _recommendedProgressLabel(event);

    return GestureDetector(
      key: key,
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
              color: Colors.black.withValues(alpha: 0.08),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _eventImage(event["banner_url"]?.toString()),
                const SizedBox(height: 12),
                _gradientButton(
                  label: context.tr("View Details"),
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
                if (progressLabel != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          progressLabel,
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendedCard(Map<String, dynamic> event, {Key? key}) {
    final date = _formatDateRange(event);
    final time =
        "${_formatTime(event["start_time"])} - ${_formatTime(event["end_time"])}";
    final rawStatus = _applicationStatusForEvent(event);
    final actionState = _actionState(rawStatus);
    final progressLabel = _recommendedProgressLabel(event);

    return GestureDetector(
      key: key,
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
              color: Colors.black.withValues(alpha: 0.06),
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                if (progressLabel != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 12, color: Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        progressLabel,
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _applicationStatusForEvent(Map<String, dynamic> event) {
    final eventId = event["id"]?.toString();
    if (eventId == null || eventId.isEmpty) return null;

    for (final app in myApplications) {
      final appEventId = app["event_id"]?.toString() ??
          app["eventId"]?.toString() ??
          app["event"]?["id"]?.toString() ??
          app["event"]?["event_id"]?.toString();
      if (appEventId == eventId) {
        return app["status"]?.toString().toLowerCase();
      }
    }

    return null;
  }

  int? _readIntFromKeys(Map<String, dynamic> event, List<String> keys) {
    for (final key in keys) {
      final value = event[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? _recommendedProgressLabel(Map<String, dynamic> event) {
    final required = _readIntFromKeys(event, [
      "volunteers_required",
      "volunteersRequired",
      "volunteers_needed",
      "volunteersNeeded",
      "required_volunteers",
    ]);
    if (required == null || required <= 0) return null;

    final filled = _readIntFromKeys(event, [
      "accepted_count",
      "approved_count",
      "slots_filled",
      "filled_slots",
      "volunteers_filled",
    ]);
    if (filled != null) {
      return context.tr(
        "{filled}/{required} approved",
        args: {
          "filled": filled.toString(),
          "required": required.toString(),
        },
      );
    }

    final applied = _readIntFromKeys(event, [
      "applications_count",
      "applicants_count",
      "applied_count",
      "total_applications",
    ]);
    final fallback = applied ?? 0;
    return context.tr(
      "{filled}/{required} approved",
      args: {
        "filled": fallback.toString(),
        "required": required.toString(),
      },
    );
  }

  _ActionState _actionState(String? status) {
    final normalized = status?.toLowerCase() ?? "";
    if (normalized == "pending") {
      return _ActionState(context.tr("Pending"), false, Colors.orange);
    }
    if (normalized == "accepted" || normalized == "approved") {
      return _ActionState(context.tr("Approved"), false, Colors.green);
    }
    if (normalized == "rejected") {
      return _ActionState(context.tr("Rejected"), false, Colors.red);
    }
    if (normalized == "cancelled") {
      return _ActionState(context.tr("Cancelled"), false, Colors.red);
    }

    return _ActionState(
      context.tr("Apply"),
      true,
      const Color(0xFF2ECC71),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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
    // Normalize localhost to 10.0.2.2 for Android emulator
    String? normalizedUrl = url;
    if (normalizedUrl != null && normalizedUrl.contains("localhost")) {
      normalizedUrl = normalizedUrl.replaceAll("localhost", "10.0.2.2");
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 92,
        height: 92,
        color: const Color(0xFFEAF0FF),
        child: normalizedUrl == null || normalizedUrl.isEmpty
            ? const Icon(Icons.image, color: Color(0xFF2E6BE6))
            : RobustImage(
                url: normalizedUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: const Color(0xFFEAF0FF),
                  child: const Icon(Icons.image, color: Color(0xFF2E6BE6)),
                ),
              ),
      ),
    );
  }

  String _formatDateRange(Map<String, dynamic> event) {
    final startDateRaw = event["event_date"]?.toString();
    final endDateRaw = event["end_date"]?.toString();

    if (startDateRaw == null || startDateRaw.isEmpty) return "";

    final startParsed = IstDateTime.tryParse(startDateRaw);
    if (startParsed == null) return "";

    final startFormatted = IstDateTime.formatDate(startParsed);

    // If no end date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startFormatted;
    }

    final endParsed = IstDateTime.tryParse(endDateRaw);
    if (endParsed == null) return startFormatted;

    // If dates are the same, show single date
    final startDateOnly =
        DateTime(startParsed.year, startParsed.month, startParsed.day);
    final endDateOnly =
        DateTime(endParsed.year, endParsed.month, endParsed.day);

    if (startDateOnly == endDateOnly) {
      return startFormatted;
    }

    // Show date range for multi-day events
    final endFormatted = IstDateTime.formatDate(endParsed);
    return "$startFormatted - $endFormatted";
  }

  String _formatTime(dynamic rawTime) {
    final text = rawTime?.toString().trim() ?? "";
    if (text.isEmpty) return "";

    final parts = text.split(":");
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final hh = hour.toString().padLeft(2, "0");
        final mm = minute.toString().padLeft(2, "0");
        return "$hh:$mm";
      }
    }

    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  Widget _timelineSegment({
    required String label,
    required String value,
    required int count,
  }) {
    final selected = selectedTimeline == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTimeline = value;
            eventsTab = value == "ongoing" ? "ongoing" : "upcoming";
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? null : Colors.transparent,
            gradient: selected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
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
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primaryBlue.withValues(alpha: 0.12),
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
      ),
    );
  }

  bool _hasEventEndedForRecommendation(Map<String, dynamic> event) {
    final startDate = _parseEventDate(event["event_date"]?.toString());
    if (startDate == null) return false;

    final endDate = _parseEventDate(event["end_date"]?.toString()) ?? startDate;
    final endTime = event["end_time"]?.toString() ?? "";
    final endDateTime = endTime.trim().isEmpty
        ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)
        : _dateWithTime(endDate, endTime);

    return IstDateTime.now().isAfter(endDateTime);
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
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
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
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
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Text(
                        _unreadNotifications > 99
                            ? "99+"
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
              await _loadUnreadCount();
            },
          ),
        ],
      ),
      body: getBody(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: selectedIndex,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              onTap: (i) => setState(() => selectedIndex = i),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home),
                  label: context.tr("Home"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.event),
                  label: context.tr("Events"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.leaderboard),
                  label: context.tr("Leaderboard"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person),
                  label: context.tr("Profile"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionState {
  final String label;
  final bool isEnabled;
  final Color color;

  const _ActionState(this.label, this.isEnabled, this.color);
}
