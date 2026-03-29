import 'package:flutter/material.dart';

import '../../localization/localization_extensions.dart';
import '../../services/event_service.dart';
import '../../widgets/organiser_bottom_nav.dart';

class AttendanceFeedbackScreen extends StatefulWidget {
  final int eventId;

  const AttendanceFeedbackScreen({super.key, required this.eventId});

  @override
  State<AttendanceFeedbackScreen> createState() =>
      _AttendanceFeedbackScreenState();
}

class _AttendanceFeedbackScreenState extends State<AttendanceFeedbackScreen> {
  bool loading = true;
  bool submitting = false;
  String? errorMessage;

  Map<String, dynamic>? event;
  List<Map<String, dynamic>> approvedVolunteers = [];
  final Map<int, String> attendanceByVolunteerId = <int, String>{};
  final TextEditingController summaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    summaryController.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  String _normalizedStatus(dynamic value) {
    return (value ?? "").toString().toLowerCase().trim();
  }

  bool _isEventCompleted() {
    final status =
        _normalizedStatus(event?["computed_status"] ?? event?["status"]);
    return status == "completed";
  }

  bool _isEventInactive() {
    final status =
        _normalizedStatus(event?["computed_status"] ?? event?["status"]);
    return status == "cancelled" ||
        status == "closed" ||
        status == "deleted" ||
        status == "deleted_by_admin";
  }

  bool _isAttendanceMarked(String status) {
    return status == "present" || status == "absent";
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final fetchedEvent = await EventService.fetchEventById(widget.eventId);
      final rawApplications = await EventService.fetchApplications(widget.eventId);

      final approved = rawApplications
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) {
            final status = _normalizedStatus(row["status"]);
            return status == "approved" ||
                status == "accepted" ||
                status == "completed";
          }).toList();

      approved.sort((a, b) {
        final aName = (a["name"] ?? "").toString().toLowerCase();
        final bName = (b["name"] ?? "").toString().toLowerCase();
        return aName.compareTo(bName);
      });

      final initialAttendance = <int, String>{};
      for (final volunteer in approved) {
        final volunteerId = _asInt(volunteer["volunteer_id"] ?? volunteer["id"]);
        if (volunteerId <= 0) continue;
        final attendanceStatus = _normalizedStatus(volunteer["attendance_status"]);
        initialAttendance[volunteerId] =
            _isAttendanceMarked(attendanceStatus) ? attendanceStatus : "unmarked";
      }

      if (!mounted) return;
      setState(() {
        event = fetchedEvent;
        approvedVolunteers = approved;
        attendanceByVolunteerId
          ..clear()
          ..addAll(initialAttendance);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (submitting) return;

    final unmarkedCount = approvedVolunteers.where((row) {
      final volunteerId = _asInt(row["volunteer_id"] ?? row["id"]);
      final status = attendanceByVolunteerId[volunteerId] ?? "unmarked";
      return !_isAttendanceMarked(status);
    }).length;

    if (unmarkedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "Mark attendance for all volunteers before saving ({count} remaining).",
              args: {"count": unmarkedCount.toString()},
            ),
          ),
        ),
      );
      return;
    }

    setState(() => submitting = true);
    try {
      final attendancePayload = approvedVolunteers.map((row) {
        final volunteerId = _asInt(row["volunteer_id"] ?? row["id"]);
        return {
          "volunteerId": volunteerId,
          "status": attendanceByVolunteerId[volunteerId] ?? "unmarked",
        };
      }).toList();

      final response = await EventService.submitAttendanceFeedback(
        eventId: widget.eventId,
        attendance: attendancePayload,
        summary: summaryController.text,
      );

      if (!mounted) return;
      final message =
          (response["message"] ?? context.tr("Attendance saved")).toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
        ),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (event?["title"] ?? context.tr("Event")).toString();
    final totalCount = approvedVolunteers.length;
    final presentCount = attendanceByVolunteerId.values
        .where((status) => status == "present")
        .length;
    final absentCount = attendanceByVolunteerId.values
        .where((status) => status == "absent")
        .length;
    final unmarkedCount = totalCount - presentCount - absentCount;
    final isCompletedEvent = _isEventCompleted();
    final isInactiveEvent = _isEventInactive();
    final attendanceNote = isCompletedEvent
        ? context.tr(
            "This event is completed. Absent volunteers will receive a strike as soon as you save attendance.",
          )
        : context.tr(
            "Mark every approved volunteer as present or absent. Absent volunteers receive a strike only after the event is completed.",
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("Attendance")),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: Text(context.tr("Retry")),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Text(
                                  context.tr(
                                    "Present: {count}",
                                    args: {"count": presentCount.toString()},
                                  ),
                                ),
                                Text(
                                  context.tr(
                                    "Absent: {count}",
                                    args: {"count": absentCount.toString()},
                                  ),
                                ),
                                Text(
                                  context.tr(
                                    "Unmarked: {count}",
                                    args: {"count": unmarkedCount.toString()},
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              attendanceNote,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (approvedVolunteers.isEmpty)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              context.tr(
                                "No approved volunteers found for this event yet.",
                              ),
                              style: TextStyle(color: Colors.grey.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: approvedVolunteers.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final row = approvedVolunteers[index];
                            final volunteerId =
                                _asInt(row["volunteer_id"] ?? row["id"]);
                            final name =
                                (row["name"] ?? context.tr("Volunteer"))
                                    .toString();
                            final city = (row["city"] ?? "-").toString();
                            final selectedStatus =
                                attendanceByVolunteerId[volunteerId] ?? "unmarked";

                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr(
                                      "Location: {location}",
                                      args: {"location": city},
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: Text(context.tr("Present")),
                                        selected: selectedStatus == "present",
                                        onSelected: volunteerId <= 0 ||
                                                isInactiveEvent
                                            ? null
                                            : (_) {
                                                setState(() {
                                                  attendanceByVolunteerId[
                                                      volunteerId] = "present";
                                                });
                                              },
                                      ),
                                      ChoiceChip(
                                        label: Text(context.tr("Absent")),
                                        selected: selectedStatus == "absent",
                                        onSelected: volunteerId <= 0 ||
                                                isInactiveEvent
                                            ? null
                                            : (_) {
                                                setState(() {
                                                  attendanceByVolunteerId[
                                                      volunteerId] = "absent";
                                                });
                                              },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: summaryController,
                            maxLines: 3,
                            maxLength: 1000,
                            decoration: InputDecoration(
                              labelText: context.tr("Optional note"),
                              hintText: context.tr(
                                "Example: volunteer informed late / unreachable / left early",
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: submitting || isInactiveEvent
                                  ? null
                                  : _submitFeedback,
                              icon: submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                submitting
                                    ? context.tr("Saving...")
                                    : context.tr("Save Attendance"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isInactiveEvent)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDA4AF)),
                          ),
                          child: Text(
                            context.tr(
                              "Attendance is not available for cancelled or removed events.",
                            ),
                            style: const TextStyle(
                              color: Color(0xFF9F1239),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: const OrganiserBottomNav(
        currentIndex: 0,
        isRootScreen: false,
      ),
    );
  }
}
