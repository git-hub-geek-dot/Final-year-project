import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/event_service.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import '../../utils/application_status.dart';
import '../../utils/ist_date_time.dart';
import '../../utils/payment_format.dart';
import '../../widgets/organiser_bottom_nav.dart';
import '../chat/event_group_chat_screen.dart';
import 'edit_event_screen.dart';
import 'review_application_screen.dart';
import 'attendance_feedback_screen.dart';
import '../../widgets/robust_image.dart';
import '../../localization/localization_extensions.dart';

class EventDetailsScreen extends StatefulWidget {
  final Map event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  static const Duration _attendanceGraceWindow = Duration(hours: 48);
  bool loadingStats = true;
  bool publishingDraft = false;
  bool cancellingEvent = false;
  bool announcingEvent = false;
  bool attendanceReopenActive = false;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  int applied = 0;
  int approved = 0;
  int pending = 0;
  int rejected = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
    _loadAttendanceReopenAccess();
    _notificationSub =
        NotificationService.messageEvents.listen(_handleNotificationEvent);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  void _handleNotificationEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = (data["type"] ?? "").toString().trim().toLowerCase();
    if (type == "attendance_reopen_update") {
      final rawEventId = data["eventId"] ?? data["event_id"];
      final eventId = int.tryParse(rawEventId?.toString() ?? "");
      final currentId = int.tryParse("${widget.event["id"]}");
      if (eventId != null && currentId != null && eventId == currentId) {
        setState(() => attendanceReopenActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                "Attendance was reopened by admin. You can submit it now.",
              ),
            ),
          ),
        );
      }
      return;
    }

    if (type != "event_removed" && type != "event_deleted") {
      return;
    }

    final rawEventId = data["eventId"] ?? data["event_id"];
    final eventId = int.tryParse(rawEventId?.toString() ?? "");
    final currentId = int.tryParse("${widget.event["id"]}");
    if (eventId == null || currentId == null || eventId != currentId) {
      return;
    }

    setState(() {
      widget.event["status"] = "deleted";
      widget.event["computed_status"] = "deleted_by_admin";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr("This event was removed by admin."))),
    );
  }

  Future<void> loadStats() async {
    try {
      final list = await EventService.fetchApplications(widget.event["id"]);

      int a = list.length;
      int ap = 0, p = 0, r = 0;

      for (final x in list) {
        final s = normalizeApplicationStatus(x["status"]);

        if (s == "approved") {
          ap++;
        } else if (s == "rejected") {
          r++;
        } else if (s == "pending" || s == "waitlisted") {
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

  Future<void> _loadAttendanceReopenAccess() async {
    final eventId = int.tryParse("${widget.event["id"]}");
    if (eventId == null) return;

    try {
      final data = await ReportService.getMyReports(
        page: 1,
        limit: 50,
        status: "resolved",
        type: "event",
      );
      final items = (data["items"] as List?) ?? [];
      final now = IstDateTime.now();

      bool hasAccess = false;
      for (final raw in items) {
        if (raw is! Map) continue;
        final report = Map<String, dynamic>.from(raw);
        final targetId = int.tryParse("${report["target_id"] ?? ""}");
        final reason = (report["reason"] ?? "").toString().trim().toLowerCase();
        final actionTaken =
            (report["action_taken"] ?? "").toString().trim().toLowerCase();
        final resolvedAt = IstDateTime.tryParse(report["resolved_at"]);

        if (targetId != eventId) continue;
        if (reason != "attendance reopen request") continue;
        if (actionTaken != "reopen_attendance") continue;
        if (resolvedAt == null) continue;
        if (!now.isAfter(resolvedAt.add(const Duration(hours: 24)))) {
          hasAccess = true;
          break;
        }
      }

      if (!mounted) return;
      setState(() => attendanceReopenActive = hasAccess);
    } catch (_) {
      // Keep default false when report fetch fails.
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

  DateTime? _eventEndDateTime(Map event) {
    final rawDate = (event["end_date"] ?? event["event_date"])?.toString();
    final datePart = IstDateTime.tryParse(rawDate);
    if (datePart == null) return null;

    final rawTime = (event["end_time"] ?? "").toString().trim();
    final parsedTime = _parseTimeValue(rawTime);
    final hour = parsedTime?.hour ?? 23;
    final minute = parsedTime?.minute ?? 59;
    final second = parsedTime?.second ?? 59;

    return DateTime(
      datePart.year,
      datePart.month,
      datePart.day,
      hour,
      minute,
      second,
    );
  }

  DateTime? _parseTimeValue(String value) {
    if (value.isEmpty) return null;
    if (value.contains("T")) return IstDateTime.tryParse(value);
    final normalized = value.length == 5 ? "$value:00" : value;
    return DateTime.tryParse("2000-01-01T$normalized");
  }

  bool _isAttendanceGraceWindowOpen(Map event) {
    if (!_isCompleted(event)) return false;
    final endAt = _eventEndDateTime(event);
    if (endAt == null) return false;

    final deadline = endAt.add(_attendanceGraceWindow);
    return !IstDateTime.now().isAfter(deadline);
  }

  Future<void> _requestAttendanceReopen(Map event) async {
    final eventId = int.tryParse("${event["id"]}");
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Invalid event id"))),
      );
      return;
    }

    final detailsController = TextEditingController();
    String? detailsError;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          title: Text(context.tr("Request attendance reopen")),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    "This sends an admin report to reopen attendance for this completed event.",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (_) {
                    if (detailsError != null) {
                      setLocalState(() => detailsError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: context.tr("Reason details"),
                    hintText: context.tr(
                      "Add why attendance could not be marked within 48 hours.",
                    ),
                    errorText: detailsError,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr("Cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                if (detailsController.text.trim().isEmpty) {
                  setLocalState(() {
                    detailsError = context.tr(
                      "Please add a short reason for admin review.",
                    );
                  });
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(context.tr("Submit report")),
            ),
          ],
        ),
      ),
    );

    if (shouldSubmit != true) {
      detailsController.dispose();
      return;
    }

    try {
      await ReportService.submitReport(
        targetType: "event",
        targetId: eventId,
        reason: "Attendance reopen request",
        details: detailsController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Attendance reopen request submitted for admin review."),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      detailsController.dispose();
    }
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
        return "Removed by admin";
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
        SnackBar(content: Text(context.tr("Invalid event id"))),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Publish Event")),
        content: Text(
          context.tr("Do you want to publish this draft event now?"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr("Publish")),
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
        SnackBar(content: Text(context.tr("Event published successfully"))),
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
              title: Text(context.tr("Cancel Event")),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("Select a cancellation reason"),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ...reasonOptions.map(
                      (reason) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: reason,
                        groupValue: selectedReason,
                        title: Text(context.tr(reason)),
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
                        decoration: InputDecoration(
                          hintText: context.tr("Write cancellation reason"),
                          border: const OutlineInputBorder(),
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
                  child: Text(context.tr("Back")),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = selectedReason == "Other"
                        ? customReasonController.text.trim()
                        : selectedReason.trim();

                    if (reason.isEmpty) {
                      setDialogState(() {
                        validationError =
                            context.tr("Please provide cancellation reason");
                      });
                      return;
                    }

                    Navigator.pop(context, reason);
                  },
                  child: Text(context.tr("Cancel Event")),
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

  Future<bool> _showCancelFinalConfirmDialog(
    Map event,
    String reason,
  ) async {
    final title = (event["title"] ?? context.tr("Event")).toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Confirm cancellation")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("Please review details before cancelling this event."),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr("Event: {title}", args: {"title": title}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr("Reason: {reason}", args: {"reason": reason}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                "This will mark the event as cancelled, notify affected volunteers, and cancel active applications.",
              ),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Back")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr("Confirm")),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _cancelEvent(Map event) async {
    final eventId = int.tryParse("${event["id"]}");
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Invalid event id"))),
      );
      return;
    }

    final reason = await _showCancelReasonDialog();
    if (reason == null || reason.trim().isEmpty) return;

    final confirmed =
      await _showCancelFinalConfirmDialog(event, reason.trim());
    if (!confirmed) return;

    setState(() => cancellingEvent = true);
    try {
      await EventService.cancelEvent(id: eventId, reason: reason.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Event cancelled successfully"))),
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
              title: Text(context.tr("Send Announcement")),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("Write a message for volunteers in this event."),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLength: 500,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: context.tr("Type announcement..."),
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
                  child: Text(context.tr("Cancel")),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        validationError = context.tr("Message is required");
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  icon: const Icon(Icons.send),
                  label: Text(context.tr("Send")),
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
        SnackBar(content: Text(context.tr("Invalid event id"))),
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

      final recipientLabel = recipients == 1
          ? context.tr("volunteer")
          : context.tr("volunteers");
      final successText = recipients > 0
          ? context.tr(
              "Announcement sent to {count} {label}",
              args: {
                "count": recipients.toString(),
                "label": recipientLabel,
              },
            )
          : context.tr("Announcement sent. No volunteers to notify yet.");

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
    final dailyScheduleRows = _buildDailyScheduleRows(event);
    final deadlineText = _fmtDate(event["application_deadline"]);
    final startTimeText = _fmtTime(event["start_time"]);
    final endTimeText = _fmtTime(event["end_time"]);
    final responsibilities =
        (event["responsibilities"] as List?)?.whereType<String>().toList() ??
            [];
    final volunteersRequired =
        int.tryParse(event["volunteers_required"]?.toString() ?? "") ?? 0;
    final remainingSlots = volunteersRequired - approved;
    final remainingSlotsLabel = remainingSlots < 0 ? 0 : remainingSlots;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        title: Text(context.tr("Event Details")),
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
                      event["title"] ?? context.tr("Untitled Event"),
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
                    Text(
                      context.tr("Event Overview"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    loadingStats
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              _statBox(
                                  context.tr("Applied"),
                                  applied.toString(),
                                  Icons.person),
                              _statBox(context.tr("Approved"),
                                  approved.toString(),
                                  Icons.check_circle),
                              _statBox(
                                  context.tr("Pending / Waitlisted"),
                                  pending.toString(),
                                  Icons.hourglass_bottom),
                              _statBox(context.tr("Rejected"),
                                  rejected.toString(),
                                  Icons.cancel),
                            ],
                          ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr(
                            "Volunteers Needed: {count}",
                            args: {
                              "count":
                                  (event["volunteers_required"] ?? 0).toString(),
                            },
                          ),
                        ),
                        Text(
                          context.tr(
                            "Slots Remaining: {count}",
                            args: {
                              "count": remainingSlotsLabel.toString(),
                            },
                          ),
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
                    Text(
                      context.tr("Event Info"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      Icons.location_on,
                      (event["location"] ?? context.tr("N/A")).toString(),
                    ),
                    _infoRow(
                      Icons.category,
                      (event["event_type"] ?? context.tr("N/A")).toString(),
                    ),
                    if (_paymentText(context, event) != null)
                      _infoRow(Icons.payments, _paymentText(context, event)),
                    if (_paymentClearanceText(context, event) != null)
                      _infoRow(
                        Icons.schedule,
                        _paymentClearanceText(context, event),
                      ),
                    _infoRow(Icons.calendar_today, eventDateRangeText),
                    _infoRow(Icons.access_time,
                        context.tr(
                          "Time: {start} - {end}",
                          args: {
                            "start": startTimeText,
                            "end": endTimeText,
                          },
                        )),
                    if (dailyScheduleRows.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.tr("Daily Schedules"),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...dailyScheduleRows,
                    ],
                    _infoRow(
                        Icons.timer,
                        context.tr(
                          "Application Deadline: {date}",
                          args: {"date": deadlineText},
                        )),
                  ],
                ),
              ),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("Responsibilities"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (responsibilities.isEmpty)
                      Text(context.tr("No responsibilities added")),
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
        final isOngoingEvent = _normalizedStatus(event) == "ongoing";
        final isRemovedEvent = _normalizedStatus(event) == "deleted_by_admin";
        final isWithinAttendanceGrace = _isAttendanceGraceWindowOpen(event);
        final canMarkAttendance =
            isOngoingEvent || isWithinAttendanceGrace || attendanceReopenActive;
        final canRequestAttendanceReopen =
            isCompletedEvent &&
            !isWithinAttendanceGrace &&
            !attendanceReopenActive;

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
          child: Text(context.tr("View Volunteers")),
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
          label: Text(context.tr("Edit Event")),
        );

        final markAttendanceButton = OutlinedButton.icon(
          onPressed: () {
            final eventId = int.tryParse("${event["id"]}");
            if (eventId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr("Invalid event id"))),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceFeedbackScreen(eventId: eventId),
              ),
            ).then((updated) {
              if (updated == true) {
                loadStats();
              }
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple.shade700,
            side: BorderSide(color: Colors.deepPurple.shade300),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(
            isCompletedEvent && attendanceReopenActive
                ? context.tr("Mark Attendance (admin reopened)")
                : isCompletedEvent && isWithinAttendanceGrace
                ? context.tr("Mark Attendance (48h grace)")
                : context.tr("Mark Attendance"),
          ),
        );

        final requestAttendanceReopenButton = OutlinedButton.icon(
          onPressed: () => _requestAttendanceReopen(event),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade700,
            side: BorderSide(color: Colors.orange.shade300),
          ),
          icon: const Icon(Icons.lock_reset),
          label: Text(context.tr("Request attendance reopen")),
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
          label: Text(
            announcingEvent ? context.tr("Sending...") : context.tr("Announce"),
          ),
        );

        final eventChatButton = OutlinedButton.icon(
          onPressed: () {
            final eventId = int.tryParse("${event["id"]}");
            if (eventId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr("Invalid event id"))),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventGroupChatScreen(
                  eventId: eventId,
                  eventTitle:
                      (event["title"] ?? context.tr("Event")).toString(),
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade300),
          ),
          icon: const Icon(Icons.forum_outlined),
          label: Text(context.tr("Event Chat")),
        );

        final cancelEventButton = OutlinedButton.icon(
          onPressed: (cancellingEvent || isCancelledEvent || isCompletedEvent)
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
          label: Text(
            isCompletedEvent
                ? context.tr("Event Completed")
                : isCancelledEvent
                    ? isRemovedEvent
                        ? context.tr("Event Removed")
                        : context.tr("Event Cancelled")
                    : context.tr("Cancel Event"),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDraftEvent && !isCancelledEvent) ...[
                viewVolunteersButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent && !isCancelledEvent && canMarkAttendance) ...[
                markAttendanceButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent &&
                  !isCancelledEvent &&
                  canRequestAttendanceReopen) ...[
                requestAttendanceReopenButton,
                const SizedBox(height: 10),
              ],
              if (!isDraftEvent && !isCancelledEvent) ...[
                announceButton,
                const SizedBox(height: 10),
              ],
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
            if (!isDraftEvent && !isCancelledEvent && canMarkAttendance) ...[
              markAttendanceButton,
              const SizedBox(width: 10),
            ],
            if (!isDraftEvent &&
                !isCancelledEvent &&
                canRequestAttendanceReopen) ...[
              requestAttendanceReopenButton,
              const SizedBox(width: 10),
            ],
            if (!isDraftEvent && !isCancelledEvent) ...[
              announceButton,
              const SizedBox(width: 10),
            ],
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
              child: Text(context.tr("Edit Draft")),
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
                      : Text(
                          context.tr("Publish Event"),
                          style: const TextStyle(
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

  Widget _statusChip(String text) {
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
          Text(context.tr(text)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String? text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (text == null || text.isEmpty) ? context.tr("N/A") : text,
            ),
          ),
        ],
      ),
    );
  }

  String? _paymentText(BuildContext context, Map event) {
    final type = event["event_type"]?.toString().toLowerCase();
    if (type != "paid") {
      return null;
    }

    return formatPaidPaymentAmount(
          event["payment_amount"],
          event["payment_rate_type"],
        ) ??
        context.tr("Paid event");
  }

  String? _paymentClearanceText(BuildContext context, Map event) {
    final type = event["event_type"]?.toString().toLowerCase();
    if (type != "paid") {
      return null;
    }

    final rawDate = event["payment_clearance_date"]?.toString();
    if (rawDate == null || rawDate.trim().isEmpty) {
      return null;
    }

    return context.tr(
      "Payment clears by: {date}",
      args: {"date": _fmtDate(rawDate)},
    );
  }

  String _formatEventDateRange(Map event) {
    final startDateRaw = event["event_date"]?.toString();
    final endDateRaw = event["end_date"]?.toString();

    if (startDateRaw == null || startDateRaw.isEmpty) return context.tr("N/A");

    final startDate = IstDateTime.formatDate(startDateRaw);

    // If no end date, show single date
    if (endDateRaw == null || endDateRaw.isEmpty) {
      return startDate;
    }

    final endDate = IstDateTime.formatDate(endDateRaw);

    // If dates are the same, show single date
    if (startDate == endDate) {
      return startDate;
    }

    // Show date range for multi-day events
    return "$startDate ${context.tr("to")} $endDate";
  }

  List<Widget> _buildDailyScheduleRows(Map event) {
    final rawSchedules = event["daily_schedules"];
    if (rawSchedules is! List || rawSchedules.isEmpty) {
      return const [];
    }

    if (rawSchedules.length <= 1) {
      return const [];
    }

    int dayNumber = 1;
    return rawSchedules.whereType<Map>().map((raw) {
      final schedule = Map<String, dynamic>.from(raw);
      final date = _fmtDate(schedule["date"]);
      final start = _fmtTime(schedule["start_time"]);
      final end = _fmtTime(schedule["end_time"]);
      final label = context.tr(
        "Day {number}: {date} | {time}",
        args: {
          "number": dayNumber.toString(),
          "date": date,
          "time": "$start - $end",
        },
      );
      dayNumber++;
      return _infoRow(Icons.schedule, label);
    }).toList();
  }

  static String _fmtDate(dynamic value) {
    return IstDateTime.formatDate(value);
  }

  static String _fmtTime(dynamic value) {
    return IstDateTime.formatTime(value);
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
