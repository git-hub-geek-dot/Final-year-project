import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/event_service.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../chat/event_group_chat_screen.dart';
import 'edit_event_screen.dart';
import 'review_application_screen.dart';
import '../../widgets/robust_image.dart';

class EventDetailsScreen extends StatefulWidget {
  final Map event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool loadingStats = true;
  bool publishingDraft = false;
  bool cancellingEvent = false;
  bool announcingEvent = false;

  int applied = 0;
  int approved = 0;
  int pending = 0;
  int rejected = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    try {
      final list = await EventService.fetchApplications(widget.event["id"]);

      int a = list.length;
      int ap = 0, p = 0, r = 0;

      for (final x in list) {
        final s = (x["status"] ?? "pending").toString().toLowerCase();

        if (s == "accepted" || s == "approved") {
          ap++;
        } else if (s == "rejected") {
          r++;
        } else {
          p++;
        }
      }

      setState(() {
        applied = a;
        approved = ap;
        pending = p;
        rejected = r;
        loadingStats = false;
      });
    } catch (_) {
      setState(() => loadingStats = false);
    }
  }

  bool _isDraft(Map event) {
    final text = _normalizedStatus(event);
    return text == "draft";
  }

  bool _isCancelled(Map event) {
    final text = _normalizedStatus(event);
    return text == "cancelled" ||
        text == "closed" ||
        text == "deleted" ||
        text == "deleted_by_admin";
  }

  bool _isCompleted(Map event) {
    return _normalizedStatus(event) == "completed";
  }

  String _normalizedStatus(Map event) {
    final text = (event["computed_status"] ?? event["status"] ?? "")
        .toString()
        .toLowerCase();
    if (text == "closed") return "cancelled";
    if (text == "deleted" || text == "deleted_by_admin") {
      return "deleted_by_admin";
    }
    return text;
  }

  String _statusText(Map event) {
    switch (_normalizedStatus(event)) {
      case "deleted_by_admin":
        return "Removed by Admin";
      case "cancelled":
        return "Cancelled";
      case "completed":
        return "Completed";
      case "draft":
        return "Draft";
      case "ongoing":
        return "Ongoing";
      case "upcoming":
      case "open":
        return "Upcoming";
      default:
        final raw = (event["computed_status"] ?? event["status"] ?? "upcoming")
            .toString();
        return raw.isEmpty ? "Upcoming" : raw;
    }
  }

  Future<void> _publishDraft(Map event) async {
    final eventId = int.tryParse("${event["id"]}");
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid event id")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Publish Event"),
        content: const Text(
          "Do you want to publish this draft event now?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Publish"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => publishingDraft = true);
    try {
      await EventService.publishDraftEvent(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event published successfully")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => publishingDraft = false);
    }
  }

  Future<String?> _showCancelReasonDialog() async {
    final reasonOptions = [
      "Low volunteer turnout",
      "Bad weather conditions",
      "Venue unavailable",
      "Safety or security concerns",
      "Permission or compliance issue",
      "Budget or resource constraints",
      "Organizer unavailable",
      "Other",
    ];

    String selectedReason = reasonOptions.first;
    final customReasonController = TextEditingController();
    String? validationError;

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isOther = selectedReason == "Other";
            return AlertDialog(
              title: const Text("Cancel Event"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select a cancellation reason",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ...reasonOptions.map(
                      (reason) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: reason,
                        groupValue: selectedReason,
                        title: Text(reason),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedReason = value;
                            validationError = null;
                          });
                        },
                      ),
                    ),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customReasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: "Write cancellation reason",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (validationError != null) {
                            setDialogState(() => validationError = null);
                          }
                        },
                      ),
                    ],
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = selectedReason == "Other"
                        ? customReasonController.text.trim()
                        : selectedReason.trim();

                    if (reason.isEmpty) {
                      setDialogState(() {
                        validationError = "Please provide cancellation reason";
                      });
                      return;
                    }

                    Navigator.pop(context, reason);
                  },
                  child: const Text("Cancel Event"),
                ),
              ],
            );
          },
        );
      },
    );

    customReasonController.dispose();
    return chosen;
  }

  Future<void> _cancelEvent(Map event) async {
    final eventId = int.tryParse("${event["id"]}");
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid event id")),
      );
      return;
    }

    final reason = await _showCancelReasonDialog();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => cancellingEvent = true);
    try {
      await EventService.cancelEvent(id: eventId, reason: reason.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event cancelled successfully")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => cancellingEvent = false);
    }
  }

  Future<String?> _showAnnouncementDialog() async {
    final controller = TextEditingController();
    String? validationError;

    final message = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Send Announcement"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Write a message for volunteers in this event.",
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLength: 500,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Type announcement...",
                      border: const OutlineInputBorder(),
                      errorText: validationError,
                    ),
                    onChanged: (_) {
                      if (validationError != null) {
                        setDialogState(() => validationError = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        validationError = "Message is required";
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  icon: const Icon(Icons.send),
                  label: const Text("Send"),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return message;
  }

  Future<void> _announceEvent(Map event) async {
    final eventId = int.tryParse("${event["id"]}");
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid event id")),
      );
      return;
    }

    final message = await _showAnnouncementDialog();
    if (message == null || message.trim().isEmpty) return;

    setState(() => announcingEvent = true);
    try {
      final recipients = await EventService.announceEvent(
        id: eventId,
        message: message.trim(),
      );
      if (!mounted) return;

      final recipientLabel = recipients == 1 ? "volunteer" : "volunteers";
      final successText = recipients > 0
          ? "Announcement sent to $recipients $recipientLabel"
          : "Announcement sent. No volunteers to notify yet.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successText)),
      );
    } catch (e) {
      if (!mounted) return;
      final error = e.toString().replaceFirst("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } finally {
      if (mounted) setState(() => announcingEvent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isDraftEvent = _isDraft(event);
    final bannerUrl = event["banner_url"];
    final status = _statusText(event);
    final eventDateText = _fmtDate(event["event_date"]);
    final eventDateRangeText = _formatEventDateRange(event);
    final deadlineText = _fmtDate(event["application_deadline"]);
    final startTimeText = _fmtTime(event["start_time"]);
    final endTimeText = _fmtTime(event["end_time"]);
    final responsibilities =
        (event["responsibilities"] as List?)?.whereType<String>().toList() ??
            [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Event Details"),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 200,
                child: bannerUrl != null && bannerUrl.toString().isNotEmpty
                    ? kIsWeb
                        ? RobustImage(
                            url: bannerUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorWidget: _fallbackBanner(),
                          )
                        : RobustImage(
                            url: bannerUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorWidget: _fallbackBanner(),
                          )
                    : _fallbackBanner(),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event["title"] ?? "Untitled Event",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _statusChip(status),
                        const SizedBox(width: 10),
                        Text(
                          eventDateText,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _actionButtons(event),
                  ],
                ),
              ),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Event Overview",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    loadingStats
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              _statBox(
                                  "Applied", applied.toString(), Icons.person),
                              _statBox("Approved", approved.toString(),
                                  Icons.check_circle),
                              _statBox("Pending", pending.toString(),
                                  Icons.hourglass_bottom),
                              _statBox("Rejected", rejected.toString(),
                                  Icons.cancel),
                            ],
                          ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            "Volunteers Needed: ${event["volunteers_required"] ?? 0}"),
                        Text(
                          "Slots Remaining: ${(event["volunteers_required"] ?? 0) - approved}",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Event Info",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Icons.location_on, event["location"]),
                    _infoRow(Icons.category, event["event_type"]),
                    _infoRow(Icons.calendar_today, eventDateRangeText),
                    _infoRow(Icons.access_time,
                        "Time: $startTimeText - $endTimeText"),
                    _infoRow(
                        Icons.timer, "Application Deadline: $deadlineText"),
                  ],
                ),
              ),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Responsibilities",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (responsibilities.isEmpty)
                      const Text("No responsibilities added"),
                    if (responsibilities.isNotEmpty)
                      ...responsibilities.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isDraftEvent) _draftBottomActions(event),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const OrganiserBottomNav(
        currentIndex: 0,
        isRootScreen: false,
      ),
    );
  }

  Widget _actionButtons(Map event) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        final isDraftEvent = _isDraft(event);
        final isCancelledEvent = _isCancelled(event);
        final isCompletedEvent = _isCompleted(event);

        final viewVolunteersButton = ElevatedButton(
          onPressed: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewApplicationsScreen(eventId: event["id"]),
              ),
            );

            if (updated == true) {
              loadStats();
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            elevation: 2,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: const Text("View Volunteers"),
        );

        final editEventButton = OutlinedButton.icon(
          onPressed: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditEventScreen(event: event),
              ),
            );
            if (updated == true) {
              Navigator.pop(context, true);
            }
          },
          icon: const Icon(Icons.edit),
          label: const Text("Edit Event"),
        );

        final announceButton = OutlinedButton.icon(
          onPressed: announcingEvent ? null : () => _announceEvent(event),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: Colors.blue.shade300),
          ),
          icon: announcingEvent
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                )
              : const Icon(Icons.campaign),
          label: Text(announcingEvent ? "Sending..." : "Announce"),
        );

        final eventChatButton = OutlinedButton.icon(
          onPressed: () {
            final eventId = int.tryParse("${event["id"]}");
            if (eventId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invalid event id")),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventGroupChatScreen(
                  eventId: eventId,
                  eventTitle: (event["title"] ?? "Event").toString(),
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade300),
          ),
          icon: const Icon(Icons.forum_outlined),
          label: const Text("Event Chat"),
        );

        final cancelEventButton = OutlinedButton.icon(
          onPressed: (cancellingEvent || isCancelledEvent)
              ? null
              : () => _cancelEvent(event),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade400),
          ),
          icon: cancellingEvent
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.red.shade400,
                    ),
                  ),
                )
              : const Icon(Icons.event_busy),
          label: Text(isCancelledEvent ? "Event Cancelled" : "Cancel Event"),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDraftEvent && !isCancelledEvent) ...[
                viewVolunteersButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent && !isCancelledEvent) ...[
                announceButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent && !isCancelledEvent && !isCompletedEvent) ...[
              if (!isDraftEvent && !isCancelledEvent) ...[
                eventChatButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent && !isCancelledEvent && !isCompletedEvent) ...[
                editEventButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent) cancelEventButton,
            ],
          );
        }

        return Row(
          children: [
            if (!isDraftEvent && !isCancelledEvent) ...[
              Expanded(child: viewVolunteersButton),
              const SizedBox(width: 10),
            ],
            if (!isDraftEvent && !isCancelledEvent) ...[
              announceButton,
              const SizedBox(width: 10),
            ],
            if (!isDraftEvent && !isCancelledEvent && !isCompletedEvent) ...[
            if (!isDraftEvent && !isCancelledEvent) ...[
              eventChatButton,
              const SizedBox(width: 10),
            ],
            if (!isDraftEvent && !isCancelledEvent && !isCompletedEvent) ...[
              editEventButton,
              const SizedBox(width: 10),
            ],
            if (!isDraftEvent) cancelEventButton,
          ],
        );
      },
    );
  }

  Widget _draftBottomActions(Map event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: publishingDraft
                  ? null
                  : () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditEventScreen(event: event),
                        ),
                      );
                      if (updated == true && mounted) {
                        Navigator.pop(context, true);
                      }
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              child: const Text("Edit Draft"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: publishingDraft ? null : () => _publishDraft(event),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: publishingDraft
                      ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                      : const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                        ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: publishingDraft
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Publish Event",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _fallbackBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF22C55E)]),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.white),
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _statusChip(String text) {
    final normalized = text.toLowerCase();
    final isCancelled = normalized.contains("cancel");
    final isCompleted = normalized.contains("complete");
    final isDraft = normalized.contains("draft");
    final isDeleted = normalized.contains("removed");

    final bgColor = isDeleted
        ? const Color(0xFFF3F4F6)
        : isCancelled
        ? const Color(0xFFFEE2E2)
        : isCompleted
            ? const Color(0xFFEDE9FE)
            : isDraft
                ? const Color(0xFFE5E7EB)
                : Colors.green.shade100;
    final dotColor = isDeleted
        ? const Color(0xFF6B7280)
        : isCancelled
        ? const Color(0xFFDC2626)
        : isCompleted
            ? const Color(0xFF7C3AED)
            : isDraft
                ? const Color(0xFF4B5563)
                : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: dotColor),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String? text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(text ?? "-")),
        ],
      ),
    );
  }

  static String _formatEventDateRange(Map event) {
    final startDateRaw = event["event_date"]?.toString();
    final endDateRaw = event["end_date"]?.toString();

    if (startDateRaw == null || startDateRaw.isEmpty) return "-";

    final startDate = startDateRaw.split("T")[0];

    // If no end date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startDate;
    }

    final endDate = endDateRaw.split("T")[0];

    // If dates are the same, show single date
    if (startDate == endDate) {
      return startDate;
    }

    // Show date range for multi-day events
    return "$startDate to $endDate";
  }

  static String _fmtDate(dynamic value) {
    if (value == null) return "-";
    final text = value.toString();
    if (text.isEmpty) return "-";
    return text.split("T")[0];
  }

  static String _fmtTime(dynamic value) {
    if (value == null) return "-";
    final text = value.toString();
    if (text.isEmpty) return "-";
    return text.split(".")[0];
  }
}

class _statBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _statBox(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
