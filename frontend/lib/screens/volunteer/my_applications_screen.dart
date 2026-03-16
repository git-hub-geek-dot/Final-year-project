import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/event_service.dart';
import '../../services/token_service.dart';
import '../../utils/ist_date_time.dart';
import 'view_event_screen.dart';

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  bool loading = true;
  String? errorMessage;
  List applications = [];
  int? cancellingApplicationId;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchMyApplications();
  }

  Future<void> fetchMyApplications() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final token = await TokenService.getToken();

      if (token == null || token.isEmpty) {
        setState(() {
          loading = false;
          errorMessage = "Token not found. Please login again.";
        });
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/applications/my");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("STATUS => ${response.statusCode}");
      print("BODY => ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // ✅ handle both formats:
        // 1) {applications: [...]}
        // 2) [...] direct list
        if (decoded is Map && decoded["applications"] is List) {
          applications = decoded["applications"];
        } else if (decoded is List) {
          applications = decoded;
        } else {
          applications = [];
        }

        setState(() {
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = "Error ${response.statusCode}: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> openEventDetails(int eventId) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final event = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewEventScreen(event: event),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load event details")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load event details")),
      );
    }
  }

  String _normalizedStatus(String status) {
    final normalized = status.toLowerCase();
    if (normalized == "accepted") return "approved";
    return normalized;
  }

  Color statusColor(String status) {
    switch (_normalizedStatus(status)) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.red;
      case "waitlisted":
        return Colors.amber.shade700;
      case "completed":
        return Colors.blueGrey;
      case "pending":
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String statusLabel(String status) {
    switch (_normalizedStatus(status)) {
      case "approved":
        return "Approved";
      case "rejected":
        return "Rejected";
      case "cancelled":
        return "Cancelled";
      case "waitlisted":
        return "Waitlisted";
      case "completed":
        return "Completed";
      case "pending":
        return "Pending";
      default:
        return status;
    }
  }

  bool _isCancelableStatus(String status) {
    return _normalizedStatus(status) == "approved";
  }

  String _normalizedAttendanceStatus(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized == "present" || normalized == "absent") {
      return normalized;
    }
    return "unmarked";
  }

  DateTime? _parseEventStartDateTime(Map app) {
    final eventDateRaw = app["event_date"]?.toString();
    if (eventDateRaw == null || eventDateRaw.isEmpty) return null;

    final eventDate = IstDateTime.tryParse(eventDateRaw);
    if (eventDate == null) return null;

    final startTimeRaw = app["start_time"]?.toString();
    if (startTimeRaw == null || startTimeRaw.isEmpty) {
      return DateTime(eventDate.year, eventDate.month, eventDate.day);
    }

    final parsedTime = DateTime.tryParse(startTimeRaw);
    int hour = parsedTime?.hour ?? 0;
    int minute = parsedTime?.minute ?? 0;
    int second = parsedTime?.second ?? 0;
    if (parsedTime == null) {
      final parts = startTimeRaw.split(":");
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
        second = int.tryParse(parts.length >= 3 ? parts[2] : "0") ?? 0;
      }
    }

    return DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      hour,
      minute,
      second,
    );
  }

  double? _hoursBeforeEvent(Map app) {
    final start = _parseEventStartDateTime(app);
    if (start == null) return null;
    return start.difference(IstDateTime.now()).inMinutes / 60.0;
  }

  bool _hasEventStarted(Map app) {
    final hoursBefore = _hoursBeforeEvent(app);
    return hoursBefore != null && hoursBefore <= 0;
  }

  bool _isWithinLockWindow(Map app) {
    final hoursBefore = _hoursBeforeEvent(app);
    return hoursBefore != null && hoursBefore > 0 && hoursBefore <= 48;
  }

  bool _isEventCompleted(Map app) {
    if (app["event_completed"] == true) return true;

    final eventStatus = (app["event_status"] ?? "").toString().toLowerCase();
    return eventStatus == "completed" ||
        _normalizedStatus((app["status"] ?? "").toString()) == "completed";
  }

  bool _canCancelApplication(Map app) {
    final status = (app["status"] ?? "pending").toString();
    return _isCancelableStatus(status) &&
        !_isEventCompleted(app) &&
        !_hasEventStarted(app);
  }

  String _formatEventDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "Date not available";

    final parsed = IstDateTime.tryParse(rawDate);
    if (parsed == null) {
      return rawDate;
    }

    final day = parsed.day.toString().padLeft(2, "0");
    final month = parsed.month.toString().padLeft(2, "0");
    return "$day/$month/${parsed.year}";
  }

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return "";
    final text = rawTime.toString();
    if (text.isEmpty) return "";

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      final hour = parsed.hour.toString().padLeft(2, "0");
      final minute = parsed.minute.toString().padLeft(2, "0");
      return "$hour:$minute";
    }

    final parts = text.split(":");
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, "0");
      final minute = parts[1].padLeft(2, "0");
      return "$hour:$minute";
    }

    return text;
  }

  String _eventMeta(Map app) {
    final parts = <String>[];
    parts.add(_formatEventDate(app["event_date"]?.toString()));

    final start = _formatTime(app["start_time"]);
    final end = _formatTime(app["end_time"]);
    if (start.isNotEmpty && end.isNotEmpty) {
      parts.add("$start - $end");
    } else if (start.isNotEmpty) {
      parts.add(start);
    }

    return parts.join("  |  ");
  }

  String? _statusDescription(Map app) {
    final status = _normalizedStatus((app["status"] ?? "pending").toString());
    final attendanceStatus = _normalizedAttendanceStatus(
      (app["attendance_status"] ?? "unmarked").toString(),
    );
    final adminCancelReason =
        (app["admin_cancel_reason"] ?? "").toString().trim();
    final volunteerCancelReason =
        (app["volunteer_cancel_reason"] ?? "").toString().trim();

    if (_isEventCompleted(app)) {
      if (attendanceStatus == "present") {
        return "Your attendance was marked present for this event.";
      }
      if (attendanceStatus == "absent") {
        return "You were marked absent for this event.";
      }
    }

    switch (status) {
      case "pending":
        return "Your application is under review.";
      case "waitlisted":
        return "This event is full right now. You will be notified if a spot opens.";
      case "approved":
        if (_isEventCompleted(app)) {
          return "You were approved for this event. The event has now ended.";
        }
        return "You are confirmed for this event.";
      case "rejected":
        return "This application was not approved.";
      case "cancelled":
        if (adminCancelReason.isNotEmpty) {
          return "Cancelled by admin. Reason: $adminCancelReason";
        }
        if (volunteerCancelReason.isNotEmpty) {
          return "You cancelled your participation. Reason: $volunteerCancelReason";
        }
        return "This application was cancelled.";
      case "completed":
        return "Your participation for this event is completed.";
      default:
        return null;
    }
  }

  String? _appealStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "eligible":
        return "Appeal available";
      case "pending":
        return "Appeal pending";
      case "approved":
        return "Appeal approved";
      case "rejected":
        return "Appeal rejected";
      default:
        return null;
    }
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Widget> _buildInfoChips(Map app) {
    final chips = <Widget>[];
    final strikeIssued = app["strike_issued"] == true;
    final warningIssued = app["warning_issued"] == true;
    final attendanceStatus = _normalizedAttendanceStatus(
      (app["attendance_status"] ?? "unmarked").toString(),
    );
    final appealStatus = (app["strike_appeal_status"] ?? "none").toString();
    final appealLabel = _appealStatusLabel(appealStatus);

    if (_isEventCompleted(app)) {
      chips.add(_infoChip("Event completed", Colors.blueGrey));
    }
    if (attendanceStatus == "present") {
      chips.add(_infoChip("Attendance present", Colors.green));
    } else if (attendanceStatus == "absent") {
      chips.add(_infoChip("Attendance absent", Colors.deepOrange));
    }
    if (warningIssued) {
      chips.add(_infoChip("Warning issued", Colors.deepOrange));
    }
    if (strikeIssued) {
      chips.add(_infoChip("Strike applied", Colors.redAccent));
    }
    if (appealLabel != null) {
      final Color appealColor;
      switch (appealStatus.toLowerCase()) {
        case "approved":
          appealColor = Colors.green;
          break;
        case "rejected":
          appealColor = Colors.red;
          break;
        case "pending":
          appealColor = Colors.blue;
          break;
        default:
          appealColor = Colors.orange;
      }
      chips.add(_infoChip(appealLabel, appealColor));
    }

    return chips;
  }

  Future<void> _cancelApplication(Map app) async {
    final appIdRaw = app["id"];
    final appId =
        appIdRaw is int ? appIdRaw : int.tryParse(appIdRaw.toString());
    if (appId == null) return;

    if (_isEventCompleted(app) || _hasEventStarted(app)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This event has already started. Cancellation is no longer available.",
          ),
        ),
      );
      return;
    }

    final hoursBefore = _hoursBeforeEvent(app);
    final isWithinLockWindow = _isWithinLockWindow(app);
    final title = (app["title"] ?? "this event").toString();

    final reasonController = TextEditingController();
    String? documentUrl;
    bool uploadingDoc = false;
    String? reasonError;
    String? documentError;

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            String policyText;
            if (isWithinLockWindow) {
              policyText =
                  "This event starts in less than 48 hours. Cancelling now applies an immediate strike."
                  " Supporting document upload is mandatory to continue.";
            } else if (hoursBefore != null && hoursBefore <= 72) {
              policyText =
                  "This cancellation is within 48-72 hours before the event. You will receive a warning."
                  " Repeated cancellations without a reason may lead to a strike.";
            } else {
              policyText =
                  "This cancellation is outside the strike window. No strike will be applied.";
            }

            return AlertDialog(
              title: const Text("Cancel Participation"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Event: $title"),
                    const SizedBox(height: 10),
                    Text(
                      policyText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      onChanged: (_) {
                        if (reasonError != null) {
                          setLocalState(() => reasonError = null);
                        }
                      },
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: isWithinLockWindow
                            ? "Reason *"
                            : "Reason (optional but recommended)",
                        helperText: isWithinLockWindow
                            ? "Mandatory for cancellations within 48 hours"
                            : null,
                        errorText: reasonError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWithinLockWindow
                              ? "Supporting document *"
                              : "Supporting document",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                documentUrl == null
                                    ? (isWithinLockWindow
                                        ? "Mandatory for cancellations within 48 hours"
                                        : "No supporting document uploaded")
                                    : "Supporting document attached",
                                style: TextStyle(
                                  color: documentUrl == null
                                      ? Colors.black54
                                      : Colors.green,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: uploadingDoc
                                  ? null
                                  : () async {
                                      final picked = await _picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 80,
                                      );
                                      if (picked == null) return;

                                      setLocalState(() => uploadingDoc = true);
                                      try {
                                        final uploaded =
                                            await EventService.uploadImage(
                                                picked);
                                        setLocalState(() {
                                          documentUrl = uploaded;
                                          documentError = null;
                                        });
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Failed to upload document: $e",
                                            ),
                                          ),
                                        );
                                      } finally {
                                        setLocalState(
                                            () => uploadingDoc = false);
                                      }
                                    },
                              icon: uploadingDoc
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: const Text("Upload"),
                            ),
                          ],
                        ),
                        if (documentError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            documentError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Keep"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (isWithinLockWindow) {
                      final trimmedReason = reasonController.text.trim();
                      setLocalState(() {
                        reasonError = trimmedReason.isEmpty
                            ? "Reason is mandatory within 48 hours"
                            : null;
                        documentError = documentUrl == null
                            ? "Supporting document is mandatory within 48 hours"
                            : null;
                      });

                      if (trimmedReason.isEmpty || documentUrl == null) {
                        return;
                      }
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text("Confirm Cancel"),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceed != true) return;

    setState(() => cancellingApplicationId = appId);
    try {
      final response = await EventService.cancelMyApplication(
        applicationId: appId,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
        supportingDocumentUrl: documentUrl,
      );

      if (!mounted) return;
      final strikeIssued = response["strikeIssued"] == true;
      final warningIssued = response["warningIssued"] == true;

      final message = strikeIssued
          ? "Participation cancelled. A strike was applied."
          : warningIssued
              ? "Participation cancelled. Warning issued for 48-72 hour window."
              : "Participation cancelled.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await fetchMyApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => cancellingApplicationId = null);
      }
    }
  }

  Future<void> _submitStrikeAppeal(Map app) async {
    final appIdRaw = app["id"];
    final appId =
        appIdRaw is int ? appIdRaw : int.tryParse(appIdRaw.toString());
    if (appId == null) return;

    final reasonController = TextEditingController();
    String? documentUrl;
    bool uploadingDoc = false;

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text("Submit Strike Appeal"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Supporting document is mandatory for strike removal review.",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Appeal reason",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          documentUrl == null
                              ? "No document uploaded"
                              : "Document uploaded",
                          style: TextStyle(
                            color: documentUrl == null
                                ? Colors.black54
                                : Colors.green,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: uploadingDoc
                            ? null
                            : () async {
                                final picked = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                );
                                if (picked == null) return;

                                setLocalState(() => uploadingDoc = true);
                                try {
                                  final uploaded =
                                      await EventService.uploadImage(picked);
                                  setLocalState(() => documentUrl = uploaded);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Upload failed: $e")),
                                  );
                                } finally {
                                  setLocalState(() => uploadingDoc = false);
                                }
                              },
                        icon: uploadingDoc
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: const Text("Upload"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (reasonController.text.trim().isEmpty ||
                      documentUrl == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text("Reason and supporting document are required"),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text("Submit Appeal"),
              ),
            ],
          ),
        );
      },
    );

    if (proceed != true || documentUrl == null) return;

    try {
      await EventService.submitStrikeAppeal(
        applicationId: appId,
        reason: reasonController.text.trim(),
        supportingDocumentUrl: documentUrl!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Strike appeal submitted")),
      );
      await fetchMyApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit appeal: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Applications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMyApplications,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : applications.isEmpty
                  ? const Center(child: Text("No applications found"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: applications.length,
                       itemBuilder: (context, index) {
                         final app = applications[index];

                         final title = app["title"] ?? "Unknown Event";
                         final location = app["location"] ?? "";
                         final status = _normalizedStatus(
                           (app["status"] ?? "pending").toString(),
                         );
                         final attendanceStatus = _normalizedAttendanceStatus(
                           (app["attendance_status"] ?? "unmarked").toString(),
                         );
                         final appIdRaw = app["id"];
                         final appId = appIdRaw is int
                             ? appIdRaw
                             : int.tryParse(appIdRaw.toString());
                         final canCancel = _canCancelApplication(app);
                         final isWithinLockWindow = _isWithinLockWindow(app);
                         final isCancelling = appId != null &&
                             cancellingApplicationId != null &&
                             appId == cancellingApplicationId;
                         final strikeIssued = app["strike_issued"] == true;
                         final appealStatus =
                             (app["strike_appeal_status"] ?? "none")
                                 .toString()
                                 .toLowerCase();
                         final canAppeal = strikeIssued &&
                             (appealStatus == "eligible" ||
                                 appealStatus == "none");
                         final infoChips = _buildInfoChips(app);
                         final statusDescription = _statusDescription(app);
                         final chipLabel = attendanceStatus == "absent"
                             ? "ATTENDANCE ABSENT"
                             : statusLabel(status).toUpperCase();
                         final chipColor = attendanceStatus == "absent"
                             ? Colors.deepOrange
                             : statusColor(status);

                         return Card(
                           margin: const EdgeInsets.only(bottom: 12),
                           clipBehavior: Clip.antiAlias,
                           child: InkWell(
                             onTap: () async {
                               final raw = app["event_id"];
                               final eventId = raw is int
                                   ? raw
                                   : int.tryParse(raw?.toString() ?? "");
                               if (eventId == null) return;
                               await openEventDetails(eventId);
                             },
                             child: Padding(
                               padding: const EdgeInsets.all(16),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Row(
                                     crossAxisAlignment:
                                         CrossAxisAlignment.start,
                                     children: [
                                       Expanded(
                                         child: Column(
                                           crossAxisAlignment:
                                               CrossAxisAlignment.start,
                                           children: [
                                             Text(
                                               title.toString(),
                                               style: const TextStyle(
                                                 fontSize: 16,
                                                 fontWeight: FontWeight.w700,
                                               ),
                                             ),
                                             const SizedBox(height: 4),
                                             if (location.toString().isNotEmpty)
                                               Text(
                                                 location.toString(),
                                                 style: TextStyle(
                                                   color: Colors.grey.shade700,
                                                 ),
                                               ),
                                             const SizedBox(height: 4),
                                             Text(
                                               _eventMeta(app),
                                               style: TextStyle(
                                                 color: Colors.grey.shade600,
                                                 fontSize: 12,
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                       Chip(
                                         label: Text(
                                          chipLabel,
                                         ),
                                         backgroundColor:
                                             chipColor.withOpacity(0.15),
                                         labelStyle: TextStyle(
                                          color: chipColor,
                                         ),
                                         side: BorderSide(
                                           color:
                                               chipColor.withOpacity(0.25),
                                         ),
                                       ),
                                     ],
                                   ),
                                   if (statusDescription != null) ...[
                                     const SizedBox(height: 10),
                                     Text(
                                       statusDescription,
                                       style: TextStyle(
                                         color: Colors.grey.shade800,
                                         height: 1.35,
                                       ),
                                     ),
                                   ],
                                   if (infoChips.isNotEmpty) ...[
                                     const SizedBox(height: 12),
                                     Wrap(
                                       spacing: 8,
                                       runSpacing: 8,
                                       children: infoChips,
                                     ),
                                   ],
                                   if (canCancel || canAppeal) ...[
                                     const SizedBox(height: 12),
                                     Wrap(
                                       spacing: 8,
                                       runSpacing: 8,
                                       children: [
                                         if (canCancel)
                                           OutlinedButton(
                                             onPressed: isCancelling
                                                 ? null
                                                 : () => _cancelApplication(app),
                                             child: isCancelling
                                                 ? const SizedBox(
                                                     width: 14,
                                                     height: 14,
                                                     child:
                                                         CircularProgressIndicator(
                                                       strokeWidth: 2,
                                                     ),
                                                   )
                                                 : Text(
                                                     isWithinLockWindow
                                                         ? "Cancel participation"
                                                         : "Cancel",
                                                   ),
                                           ),
                                         if (canAppeal)
                                           TextButton(
                                             onPressed:
                                                 () => _submitStrikeAppeal(app),
                                             child: const Text("Submit appeal"),
                                           ),
                                       ],
                                     ),
                                   ],
                                 ],
                               ),
                             ),
                           ),
                         );
                       },
                    ),
    );
  }
}
