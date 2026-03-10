import 'package:flutter/material.dart';

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
  final Set<int> absentVolunteerIds = <int>{};
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

      if (!mounted) return;
      setState(() {
        event = fetchedEvent;
        approvedVolunteers = approved;
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

    setState(() => submitting = true);
    try {
      final response = await EventService.submitAttendanceFeedback(
        eventId: widget.eventId,
        absentVolunteerIds: absentVolunteerIds.toList(),
        summary: summaryController.text,
      );

      if (!mounted) return;
      final message = (response["message"] ?? "Attendance feedback submitted")
          .toString();

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
    final title = (event?["title"] ?? "Event").toString();
    final approvedCount = approvedVolunteers.length;
    final absentCount = absentVolunteerIds.length;
    final presentCount = (approvedCount - absentCount).clamp(0, approvedCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Feedback"),
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
                          child: const Text("Retry"),
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
                            Text("Present: $presentCount"),
                            Text("Absent: $absentCount"),
                            const SizedBox(height: 6),
                            Text(
                              "Select volunteers who were absent. This will create admin reports for strike review.",
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
                              "No approved volunteers found for this event yet.",
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
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final row = approvedVolunteers[index];
                            final volunteerId =
                                _asInt(row["volunteer_id"] ?? row["id"]);
                            final name = (row["name"] ?? "Volunteer").toString();
                            final city = (row["city"] ?? "-").toString();
                            final isAbsent =
                                absentVolunteerIds.contains(volunteerId);

                            return CheckboxListTile(
                              value: isAbsent,
                              onChanged: volunteerId <= 0
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          absentVolunteerIds.add(volunteerId);
                                        } else {
                                          absentVolunteerIds.remove(volunteerId);
                                        }
                                      });
                                    },
                              title: Text(name),
                              subtitle: Text("Location: $city"),
                              secondary: const Icon(Icons.person_outline),
                              controlAffinity: ListTileControlAffinity.trailing,
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
                            decoration: const InputDecoration(
                              labelText: "Optional note for admin",
                              hintText:
                                  "Example: volunteer informed late / unreachable / no-show",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: submitting ? null : _submitFeedback,
                              icon: submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                submitting
                                    ? "Submitting..."
                                    : absentCount == 0
                                        ? "Submit: All Attended"
                                        : "Report $absentCount Absent to Admin",
                              ),
                            ),
                          ),
                        ],
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

