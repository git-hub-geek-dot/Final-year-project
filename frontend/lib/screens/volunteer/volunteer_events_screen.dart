import 'package:flutter/material.dart';

import 'view_event_screen.dart';

class VolunteerEventsScreen extends StatefulWidget {
  final List events;
  final bool loading;
  final List myApplications;
  final Future<void> Function() onRefresh;
  final String initialTab;

  const VolunteerEventsScreen({
    super.key,
    required this.events,
    required this.loading,
    required this.myApplications,
    required this.onRefresh,
    this.initialTab = "all",
  });

  @override
  State<VolunteerEventsScreen> createState() => _VolunteerEventsScreenState();
}

class _VolunteerEventsScreenState extends State<VolunteerEventsScreen> {
  String searchQuery = "";
  String selectedTab = "all"; // all | upcoming | ongoing | past
  String selectedCategory = "All Categories";
  String selectedDate = "Any Date";
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

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
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VolunteerEventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        selectedTab = widget.initialTab;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredEvents();
    final isSplitTab = selectedTab != "all";
    final split = isSplitTab ? _splitByApplication(filtered) : null;
    final openEvents = split?.open ?? const <Map<String, dynamic>>[];
    final appliedEvents = split?.applied ?? const <Map<String, dynamic>>[];
    final hasAny = filtered.isNotEmpty;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _searchRow(),
          const SizedBox(height: 12),
          _tabsRow(),
          const SizedBox(height: 12),
          if (!hasAny)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text("No events found")),
            )
          else if (!isSplitTab) ...[
            ...filtered.map(_eventCard),
          ] else ...[
            if (appliedEvents.isEmpty && selectedTab == "past")
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text("No volunteer history yet")),
              ),
            if (appliedEvents.isNotEmpty) ...[
              _sectionHeader("Applied Events"),
              const SizedBox(height: 8),
              ...appliedEvents.map(_eventCard),
              if (openEvents.isNotEmpty && selectedTab != "past")
                const SizedBox(height: 8),
            ],
            if (openEvents.isNotEmpty && selectedTab != "past") ...[
              _sectionHeader("Open Events"),
              const SizedBox(height: 8),
              ...openEvents.map(_eventCard),
            ],
          ],
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        if (showSearch)
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              autofocus: true,
              onChanged: (value) =>
                  setState(() => searchQuery = value.toLowerCase()),
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
          )
        else
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEAF0FF),
            child: IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF2E6BE6)),
              onPressed: () {
                setState(() {
                  showSearch = true;
                });
              },
              tooltip: "Search",
            ),
          ),
        const SizedBox(width: 10),
        if (!showSearch)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _appliedFiltersChips(),
            ),
          ),
        if (!showSearch) const SizedBox(width: 10),
        if (showSearch)
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEAF0FF),
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF2E6BE6)),
              onPressed: () {
                setState(() {
                  showSearch = false;
                  searchQuery = "";
                  _searchController.clear();
                });
                _searchFocus.unfocus();
              },
              tooltip: "Close search",
            ),
          ),
        if (showSearch) const SizedBox(width: 10),
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFEAF0FF),
          child: IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF2E6BE6)),
            onPressed: _openFilterSheet,
            tooltip: "Filters",
          ),
        ),
      ],
    );
  }

  Widget _appliedFiltersChips() {
    final chips = <Widget>[];

    if (selectedCategory != "All Categories") {
      chips.add(
        _filterChip(
          selectedCategory,
          onRemove: () => setState(() => selectedCategory = "All Categories"),
        ),
      );
    }

    if (selectedDate != "Any Date") {
      chips.add(
        _filterChip(
          selectedDate,
          onRemove: () => setState(() => selectedDate = "Any Date"),
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _filterChip(String label, {required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2E6BE6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF2E6BE6),
            ),
          ),
        ],
      ),
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
          Expanded(child: _tabButton("All", "all")),
          Expanded(child: _tabButton("Upcoming", "upcoming")),
          Expanded(child: _tabButton("Ongoing", "ongoing")),
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

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        String sheetCategory = selectedCategory;
        String sheetDate = selectedDate;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
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
                      "Category",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final selected = sheetCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              sheetCategory = cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Date",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: dateFilters.map((date) {
                        final selected = sheetDate == date;
                        return ChoiceChip(
                          label: Text(date),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              sheetDate = date;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                selectedCategory = "All Categories";
                                selectedDate = "Any Date";
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("Clear"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedCategory = sheetCategory;
                                selectedDate = sheetDate;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
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
        final isOngoing = dateOnly.isAtSameMomentAs(today) && !isCompleted;
      final isUpcoming = dateOnly.isAfter(today) && !isCompleted;

        final matchesTab = selectedTab == "all"
          ? true
          : selectedTab == "past"
            ? isPast
            : selectedTab == "ongoing"
              ? isOngoing
              : isUpcoming;

      final matchesDate = _matchesDateFilter(dateOnly, today);

      return matchesSearch && matchesCategory && matchesTab && matchesDate;
    }).toList();

    list.sort((a, b) {
      // For "all" tab, prioritize unapplied events
      if (selectedTab == "all") {
        final aStatus = _applicationStatusForEvent(a) ??
            (a["application_status"] ??
                    a["applicationStatus"] ??
                    a["my_application_status"] ??
                    "")
                .toString()
                .toLowerCase();
        final bStatus = _applicationStatusForEvent(b) ??
            (b["application_status"] ??
                    b["applicationStatus"] ??
                    b["my_application_status"] ??
                    "")
                .toString()
                .toLowerCase();
        
        final aIsUnapplied = aStatus.isEmpty;
        final bIsUnapplied = bStatus.isEmpty;
        
        // Unapplied events come first
        if (aIsUnapplied && !bIsUnapplied) return -1;
        if (!aIsUnapplied && bIsUnapplied) return 1;
      }
      
      // Then sort by date
      final aDate = DateTime.tryParse(a["event_date"]?.toString() ?? "");
      final bDate = DateTime.tryParse(b["event_date"]?.toString() ?? "");
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    return list;
  }

  _SplitEvents _splitByApplication(List<Map<String, dynamic>> events) {
    final open = <Map<String, dynamic>>[];
    final applied = <Map<String, dynamic>>[];

    for (final event in events) {
      final status = _applicationStatusForEvent(event) ??
          (event["application_status"] ??
                  event["applicationStatus"] ??
                  event["my_application_status"] ??
                  "")
              .toString()
              .toLowerCase();
      if (status.isEmpty) {
        open.add(event);
      } else {
        applied.add(event);
      }
    }

    return _SplitEvents(open: open, applied: applied);
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
    // Normalize localhost to 10.0.2.2 for Android emulator
    String? normalizedUrl = url;
    if (normalizedUrl != null && normalizedUrl.contains("localhost")) {
      normalizedUrl = normalizedUrl.replaceAll("localhost", "10.0.2.2");
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 72,
        color: const Color(0xFFEAF0FF),
        child: normalizedUrl == null || normalizedUrl.isEmpty
            ? const Icon(Icons.image, color: Color(0xFF2E6BE6))
            : Image.network(
                normalizedUrl,
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

class _SplitEvents {
  final List<Map<String, dynamic>> open;
  final List<Map<String, dynamic>> applied;

  const _SplitEvents({required this.open, required this.applied});
}
