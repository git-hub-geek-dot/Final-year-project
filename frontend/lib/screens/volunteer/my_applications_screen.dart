import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/event_service.dart';
import '../../services/notification_service.dart';
import '../../services/token_service.dart';
import '../../utils/ist_date_time.dart';
import '../../localization/localization_extensions.dart';
import 'view_event_screen.dart';

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen>
    with WidgetsBindingObserver {
  bool loading = true;
  String? errorMessage;
  List applications = [];
  int? cancellingApplicationId;
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchMyApplications();
    _notificationSub =
        NotificationService.messageEvents.listen(_handleNotificationEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchMyApplications();
    }
  }

  void _handleNotificationEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = (data["type"] ?? "").toString().trim().toLowerCase();
    if (type == "application_status" ||
        type == "application_cancelled" ||
        type == "waitlist_promoted" ||
        type == "attendance_updated" ||
        type == "attendance_absent_strike" ||
        type == "strike_appeal_reviewed" ||
        type == "event_cancelled" ||
        type == "event_removed" ||
        type == "event_deleted" ||
        type == "event_update" ||
        type == "event_broadcast") {
      fetchMyApplications();
    }
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
          errorMessage = context.tr("Token not found. Please login again.");
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
          errorMessage = context.tr(
            "Error {code}: {body}",
            args: {
              "code": response.statusCode.toString(),
              "body": response.body.toString(),
            },
          );
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = context.tr(
          "Error: {error}",
          args: {"error": e.toString()},
        );
      });
    }
  }

  Future<void> openEventDetails(int eventId) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/events/$eventId"),
      );

      if (!mounted) return;

      if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                "This event was removed by admin. Details are no longer available.",
              ),
            ),
          ),
        );
        await fetchMyApplications();
        return;
      }

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
        SnackBar(content: Text(context.tr("Failed to load event details"))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to load event details"))),
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
        return context.tr("Approved");
      case "rejected":
        return context.tr("Rejected");
      case "cancelled":
        return context.tr("Cancelled");
      case "waitlisted":
        return context.tr("Waitlisted");
      case "completed":
        return context.tr("Completed");
      case "pending":
        return context.tr("Pending");
      default:
        return status;
    }
  }

  bool _isCancelableStatus(String status) {
    final normalized = _normalizedStatus(status);
    return normalized == "approved" ||
        normalized == "pending" ||
        normalized == "waitlisted";
  }

  bool _isApprovedStatus(String status) {
    return _normalizedStatus(status) == "approved";
  }

  String _cancelActionLabel(String status, {bool isLocked = false}) {
    final base = _isApprovedStatus(status)
        ? context.tr("Cancel participation")
        : context.tr("Withdraw application");

    if (!isLocked) return base;

    return _isApprovedStatus(status)
        ? context.tr("Cancel participation (Locked)")
        : context.tr("Withdraw application (Locked)");
  }

  String _cancelDialogTitle(String status) {
    return _isApprovedStatus(status)
        ? context.tr("Cancel Participation")
        : context.tr("Withdraw Application");
  }

  String _confirmCancelLabel(String status) {
    return _isApprovedStatus(status)
        ? context.tr("Confirm Cancel")
        : context.tr("Confirm Withdraw");
  }

  String _cancellationSuccessMessage({
    required String status,
    required bool strikeIssued,
    required bool warningIssued,
  }) {
    if (strikeIssued) {
      return _isApprovedStatus(status)
          ? context.tr("Participation cancelled. A strike was applied.")
          : context.tr("Application withdrawn. A strike was applied.");
    }

    if (warningIssued) {
      return _isApprovedStatus(status)
          ? context.tr(
              "Participation cancelled. Warning issued for 48-72 hour window.",
            )
          : context.tr(
              "Application withdrawn. Warning issued for 48-72 hour window.",
            );
    }

    return _isApprovedStatus(status)
        ? context.tr("Participation cancelled.")
        : context.tr("Application withdrawn.");
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

  bool _isEventRemoved(Map app) {
    final eventStatus = (app["event_status"] ?? "").toString().toLowerCase();
    return eventStatus == "deleted" || eventStatus == "deleted_by_admin";
  }

  bool _isReviewClosed(Map app) {
    if (app["review_closed"] == true) return true;

    final status = _normalizedStatus((app["status"] ?? "").toString());
    if (status != "pending" && status != "waitlisted") {
      return false;
    }

    return _isEventCompleted(app);
  }

  bool _canCancelApplication(Map app) {
    final status = (app["status"] ?? "pending").toString();
    return _isCancelableStatus(status) &&
        !_isEventCompleted(app) &&
        !_hasEventStarted(app);
  }

  String _formatEventDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return context.tr("Date not available");
    }

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
    if (_isEventRemoved(app)) {
      return context.tr(
        "This event was removed by admin. Details are no longer available.",
      );
    }

    final status = _normalizedStatus((app["status"] ?? "pending").toString());
    final attendanceStatus = _normalizedAttendanceStatus(
      (app["attendance_status"] ?? "unmarked").toString(),
    );
    final adminCancelReason =
        (app["admin_cancel_reason"] ?? "").toString().trim();
    final volunteerCancelReason =
        (app["volunteer_cancel_reason"] ?? "").toString().trim();
    final cancellationSource =
        (app["cancellation_source"] ?? "").toString().trim().toLowerCase();

    if (_isEventCompleted(app)) {
      if (attendanceStatus == "present") {
        return context.tr("Your attendance was marked present for this event.");
      }
      if (attendanceStatus == "absent") {
        return context.tr("You were marked absent for this event.");
      }
    }

    if (_isReviewClosed(app)) {
      return context.tr("This event ended before your application was reviewed.");
    }

    switch (status) {
      case "pending":
        return context.tr("Your application is under review.");
      case "waitlisted":
        return context.tr(
          "This event is full right now. The organiser can review and approve waitlisted applications if a spot opens.",
        );
      case "approved":
        if (_isEventCompleted(app)) {
          return context.tr(
            "You were approved for this event. The event has now ended.",
          );
        }
        return context.tr("You are confirmed for this event.");
      case "rejected":
        return context.tr("This application was not approved.");
      case "cancelled":
        if (adminCancelReason.isNotEmpty) {
          if (cancellationSource == "organiser") {
            return context.tr(
              "Cancelled because the organiser cancelled this event. Reason: {reason}",
              args: {"reason": adminCancelReason},
            );
          }
          return context.tr(
            "Cancelled by admin. Reason: {reason}",
            args: {"reason": adminCancelReason},
          );
        }
        if (volunteerCancelReason.isNotEmpty) {
          return context.tr(
            "You cancelled your participation. Reason: {reason}",
            args: {"reason": volunteerCancelReason},
          );
        }
        return context.tr("This application was cancelled.");
      case "completed":
        return context.tr("Your participation for this event is completed.");
      default:
        return null;
    }
  }

  String? _appealStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "eligible":
        return context.tr("Appeal available");
      case "pending":
        return context.tr("Appeal pending");
      case "approved":
        return context.tr("Appeal approved");
      case "rejected":
        return context.tr("Appeal rejected");
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
      chips.add(_infoChip(context.tr("Event completed"), Colors.blueGrey));
    }
    if (_isReviewClosed(app)) {
      chips.add(_infoChip(context.tr("Review closed"), Colors.redAccent));
    }
    if (attendanceStatus == "present") {
      chips.add(_infoChip(context.tr("Attendance present"), Colors.green));
    } else if (attendanceStatus == "absent") {
      chips.add(_infoChip(context.tr("Attendance absent"), Colors.deepOrange));
    }
    if (warningIssued) {
      chips.add(_infoChip(context.tr("Warning issued"), Colors.deepOrange));
    }
    if (strikeIssued) {
      chips.add(_infoChip(context.tr("Strike applied"), Colors.redAccent));
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
    final currentStatus = _normalizedStatus((app["status"] ?? "").toString());
    final isApprovedApplication = _isApprovedStatus(currentStatus);

    if (_isEventCompleted(app) || _hasEventStarted(app)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "This event has already started. Cancellation is no longer available.",
            ),
          ),
        ),
      );
      return;
    }

    final hoursBefore = _hoursBeforeEvent(app);
    final isWithinLockWindow = _isWithinLockWindow(app);
    final title = (app["title"] ?? context.tr("this event")).toString();

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
              policyText = isApprovedApplication
                  ? context.tr(
                      "This event starts in less than 48 hours. Cancelling now applies an immediate strike. Provide a reason or upload a supporting document to continue.",
                    )
                  : context.tr(
                      "This event starts in less than 48 hours. Withdrawing now applies an immediate strike. Provide a reason or upload a supporting document to continue.",
                    );
            } else if (hoursBefore != null && hoursBefore <= 72) {
              policyText = isApprovedApplication
                  ? context.tr(
                      "This cancellation is within 48-72 hours before the event. You will receive a warning. Repeated cancellations without a reason or supporting document may lead to a strike.",
                    )
                  : context.tr(
                      "This withdrawal is within 48-72 hours before the event. You will receive a warning. Repeated withdrawals without a reason or supporting document may lead to a strike.",
                    );
            } else {
              policyText = isApprovedApplication
                  ? context.tr(
                      "This cancellation is outside the strike window. No strike will be applied.",
                    )
                  : context.tr(
                      "This withdrawal is outside the strike window. No strike will be applied.",
                    );
            }

            return AlertDialog(
              title: Text(_cancelDialogTitle(currentStatus)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        "Event: {title}",
                        args: {"title": title},
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      policyText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      onChanged: (_) {
                        if (reasonError != null || documentError != null) {
                          setLocalState(() {
                            reasonError = null;
                            documentError = null;
                          });
                        }
                      },
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.tr("Reason (optional)"),
                        helperText: context.tr(
                          "Provide reason or supporting document",
                        ),
                        errorText: reasonError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr("Supporting document (optional)"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                documentUrl == null
                                    ? context.tr(
                                        "No supporting document uploaded",
                                      )
                                    : context.tr(
                                        "Supporting document attached",
                                      ),
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
                                              context.tr(
                                                "Failed to upload document: {error}",
                                                args: {"error": e.toString()},
                                              ),
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
                              label: Text(context.tr("Upload")),
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
                  child: Text(context.tr("Keep")),
                ),
                ElevatedButton(
                  onPressed: () {
                    final trimmedReason = reasonController.text.trim();
                    final hasReason = trimmedReason.isNotEmpty;
                    final hasDocument = documentUrl != null;
                    final requiresJustification = isWithinLockWindow;
                    if (requiresJustification && !hasReason && !hasDocument) {
                      final error = context.tr(
                        "Please provide a reason or upload a supporting document",
                      );
                      setLocalState(() {
                        reasonError = error;
                        documentError = error;
                      });
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(_confirmCancelLabel(currentStatus)),
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
      final message = _cancellationSuccessMessage(
        status: currentStatus,
        strikeIssued: strikeIssued,
        warningIssued: warningIssued,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await fetchMyApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "Failed to cancel: {error}",
              args: {"error": e.toString()},
            ),
          ),
        ),
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
            title: Text(context.tr("Submit Strike Appeal")),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      "Supporting document is mandatory for strike removal review.",
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.tr("Appeal reason"),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          documentUrl == null
                              ? context.tr("No document uploaded")
                              : context.tr("Document uploaded"),
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
                                      content: Text(
                                        context.tr(
                                          "Upload failed: {error}",
                                          args: {"error": e.toString()},
                                        ),
                                      ),
                                    ),
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
                        label: Text(context.tr("Upload")),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr("Cancel")),
              ),
              ElevatedButton(
                onPressed: () {
                  if (reasonController.text.trim().isEmpty ||
                      documentUrl == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            "Reason and supporting document are required",
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: Text(context.tr("Submit Appeal")),
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
        SnackBar(content: Text(context.tr("Strike appeal submitted"))),
      );
      await fetchMyApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "Failed to submit appeal: {error}",
              args: {"error": e.toString()},
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("My Applications")),
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
                  ? Center(child: Text(context.tr("No applications found")))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: applications.length,
                       itemBuilder: (context, index) {
                         final app = applications[index];

                         final title =
                             app["title"] ?? context.tr("Unknown Event");
                         final location = app["location"] ?? "";
                         final status = _normalizedStatus(
                           (app["status"] ?? "pending").toString(),
                         );
                         final attendanceStatus = _normalizedAttendanceStatus(
                           (app["attendance_status"] ?? "unmarked").toString(),
                         );
                         final isRemoved = _isEventRemoved(app);
                         final appIdRaw = app["id"];
                         final appId = appIdRaw is int
                             ? appIdRaw
                             : int.tryParse(appIdRaw.toString());
                         final canCancel =
                             _canCancelApplication(app) && !isRemoved;
                         final isWithinLockWindow = _isWithinLockWindow(app);
                         final isCancelling = appId != null &&
                             cancellingApplicationId != null &&
                             appId == cancellingApplicationId;
                         final cancelLabel = _cancelActionLabel(
                           status,
                           isLocked: isWithinLockWindow,
                         );
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
                         final isReviewClosed = _isReviewClosed(app);
                         final chipLabel = isRemoved
                             ? context.tr("Event removed").toUpperCase()
                             : attendanceStatus == "absent"
                                 ? context.tr("Attendance absent").toUpperCase()
                                 : isReviewClosed
                                     ? context.tr("Review closed").toUpperCase()
                                     : statusLabel(status).toUpperCase();
                         final chipColor = isRemoved
                             ? Colors.grey
                             : attendanceStatus == "absent"
                                 ? Colors.deepOrange
                                 : isReviewClosed
                                     ? Colors.redAccent
                                     : statusColor(status);

                         return Card(
                           margin: const EdgeInsets.only(bottom: 12),
                           clipBehavior: Clip.antiAlias,
                           child: InkWell(
                             onTap: () async {
                               if (isRemoved) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(
                                     content: Text(
                                       context.tr(
                                         "This event was removed by admin. Details are no longer available.",
                                       ),
                                     ),
                                   ),
                                 );
                                 return;
                               }
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
                                                 : Text(cancelLabel),
                                           ),
                                        if (canAppeal)
                                          TextButton(
                                            onPressed:
                                                () => _submitStrikeAppeal(app),
                                            child: Text(
                                              context.tr("Submit appeal"),
                                            ),
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
