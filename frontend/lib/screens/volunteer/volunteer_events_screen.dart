import 'package:flutter/material.dart';

import 'view_event_screen.dart';

class VolunteerEventsScreen extends StatefulWidget {
  final List events;
  final bool loading;
  final List myApplications;
  final Future<void> Function() onRefresh;

  const VolunteerEventsScreen({
    super.key,
    required this.events,
    required this.loading,
    required this.myApplications,
    required this.onRefresh,
  });

  @override
  State<VolunteerEventsScreen> createState() => _VolunteerEventsScreenState();
}

class _VolunteerEventsScreenState extends State<VolunteerEventsScreen> {
  String searchQuery = "";
  String selectedTab = "upcoming"; // upcoming | active | past
  String selectedCategory = "All Categories";
  String selectedDate = "Any Date";

  final List<String> categories = [
    "All Categories",
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

  final List<String> dateFilters = [
    "Any Date",
    "This Week",
    "This Month",
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredEvents();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _searchRow(),
          const SizedBox(height: 12),
          _tabsRow(),
          const SizedBox(height: 10),
          _filtersRow(),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text("No events found")),
            ),
          ...filtered.map(_eventCard),
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Search",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFEAF0FF),
          child: const Icon(Icons.person, color: Color(0xFF2E6BE6)),
        ),
      ],
    );
  }

  Widget _tabsRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton("Upcoming", "upcoming")),
          Expanded(child: _tabButton("Active", "active")),
          Expanded(child: _tabButton("Past", "past")),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String value) {
    final selected = selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E6BE6) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return Row(
      children: [
        Expanded(
          child: _dropdown(
            value: selectedCategory,
            items: categories,
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedCategory = value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdown(
            value: selectedDate,
            items: dateFilters,
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedDate = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down),
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final list = widget.events.whereType<Map<String, dynamic>>().where((event) {
      final title = (event["title"] ?? "").toString().toLowerCase();
      final location = (event["location"] ?? "").toString().toLowerCase();
      final matchesSearch = title.contains(searchQuery) || location.contains(searchQuery);

      final List cats = (event["categories"] ?? []);
      final matchesCategory =
          selectedCategory == "All Categories" || cats.contains(selectedCategory);

      final date = DateTime.tryParse(event["event_date"]?.toString() ?? "");
      if (date == null) return false;

      final dateOnly = DateTime(date.year, date.month, date.day);
      final isCompleted = event["computed_status"]?.toString() == "completed";
      final isPast = dateOnly.isBefore(today) || isCompleted;
      final isActive = dateOnly.isAtSameMomentAs(today) && !isCompleted;
      final isUpcoming = dateOnly.isAfter(today) && !isCompleted;

      final matchesTab = selectedTab == "past"
          ? isPast
          : selectedTab == "active"
              ? isActive
              : isUpcoming;

      final matchesDate = _matchesDateFilter(dateOnly, today);

      return matchesSearch && matchesCategory && matchesTab && matchesDate;
    }).toList();

    list.sort((a, b) {
      final aDate = DateTime.tryParse(a["event_date"]?.toString() ?? "");
      final bDate = DateTime.tryParse(b["event_date"]?.toString() ?? "");
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    return list;
  }

  bool _matchesDateFilter(DateTime eventDate, DateTime today) {
    if (selectedDate == "Any Date") return true;

    if (selectedDate == "This Week") {
      final endOfWeek = today.add(const Duration(days: 7));
      return eventDate.isAfter(today.subtract(const Duration(days: 1))) &&
          eventDate.isBefore(endOfWeek);
    }

    if (selectedDate == "This Month") {
      return eventDate.year == today.year && eventDate.month == today.month;
    }

    return true;
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final date = _formatDate(event["event_date"]?.toString());
    final time = "${_formatTime(event["start_time"])} - ${_formatTime(event["end_time"])}";
    final statusText = event["computed_status"]?.toString() == "completed"
        ? "Closed"
        : "Open";
    final statusColor = statusText == "Open" ? Colors.green : Colors.grey;
    final rawApplicationStatus = _applicationStatusForEvent(event) ??
      (event["application_status"] ??
          event["applicationStatus"] ??
          event["my_application_status"] ??
          "")
        .toString()
        .toLowerCase();

    final isPastTab = selectedTab == "past";
    final isClosed = statusText == "Closed";
    final actionState = _actionState(rawApplicationStatus, isPastTab, isClosed);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewEventScreen(event: event),
          ),
        );
        await widget.onRefresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEAF0FF),
              child: const Icon(Icons.volunteer_activism, color: Color(0xFF2E6BE6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event["title"] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(date, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.black54),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(time, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                _eventImage(event["banner_url"]?.toString()),
                const SizedBox(height: 10),
                if (actionState != null)
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
                            await widget.onRefresh();
                          },
                        )
                      : _statusPill(actionState.label, actionState.color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _ActionState? _actionState(String status, bool isPastTab, bool isClosed) {
    if (isPastTab || isClosed) return null;

    if (status == "pending") {
      return _ActionState("Pending", false, Colors.orange);
    }
    if (status == "accepted" || status == "approved") {
      return _ActionState("Accepted", false, Colors.green);
    }
    if (status == "rejected") {
      return _ActionState("Rejected", false, Colors.red);
    }

    return _ActionState("Apply", true, const Color(0xFF2ECC71));
  }

  String? _applicationStatusForEvent(Map<String, dynamic> event) {
    final eventId = event["id"]?.toString();
    if (eventId == null || eventId.isEmpty) return null;

    for (final app in widget.myApplications) {
      final appEventId = app["event_id"]?.toString();
      if (appEventId == eventId) {
        return app["status"]?.toString().toLowerCase();
      }
    }

    return null;
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

  Widget _eventImage(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 72,
        color: const Color(0xFFEAF0FF),
        child: url == null || url.isEmpty
            ? const Icon(Icons.image, color: Color(0xFF2E6BE6))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Icon(Icons.image, color: Color(0xFF2E6BE6));
                },
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
            horizontal: compact ? 14 : 18,
            vertical: compact ? 6 : 8,
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
              fontSize: 12,
            ),
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
}

class _ActionState {
  final String label;
  final bool isEnabled;
  final Color color;

  const _ActionState(this.label, this.isEnabled, this.color);
}
