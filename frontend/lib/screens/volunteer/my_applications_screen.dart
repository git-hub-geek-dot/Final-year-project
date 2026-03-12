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

        applications = applications.where((app) {
          final status = app["status"]?.toString().toLowerCase() ?? "";
          if (status == "approved" || status == "accepted") return true;
          return !_isPastEventDate(app["event_date"]?.toString());
        }).toList();

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

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "accepted":
        return Colors.green;
      case "rejected":
      case "cancelled":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
      case "approved":
        return "Approved";
      case "rejected":
        return "Rejected";
      case "cancelled":
        return "Cancelled";
      case "pending":
        return "Pending";
      default:
        return status;
    }
  }

  bool _isPastEventDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return false;

    final parsed = IstDateTime.tryParse(rawDate);
    if (parsed == null) return false;

    final eventDateOnly = IstDateTime.startOfDay(parsed);
    final today = IstDateTime.startOfDay(IstDateTime.now());

    return eventDateOnly.isBefore(today);
  }

  bool _isCancelableStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == "approved" || normalized == "accepted";
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

  Future<void> _cancelApplication(Map app) async {
    final appIdRaw = app["id"];
    final appId =
        appIdRaw is int ? appIdRaw : int.tryParse(appIdRaw.toString());
    if (appId == null) return;

    final hoursBefore = _hoursBeforeEvent(app);
    final isWithinLockWindow = hoursBefore != null && hoursBefore <= 48;
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
                        final status = app["status"] ?? "pending";
                        final cancelReason =
                            (app["admin_cancel_reason"] ?? "").toString();
                        final appIdRaw = app["id"];
                        final appId = appIdRaw is int
                            ? appIdRaw
                            : int.tryParse(appIdRaw.toString());
                        final canCancel =
                            _isCancelableStatus(status.toString());
                        final hoursBefore = _hoursBeforeEvent(app);
                        final isWithinLockWindow =
                            hoursBefore != null && hoursBefore <= 48;
                        final isCancelling = appId != null &&
                            cancellingApplicationId != null &&
                            appId == cancellingApplicationId;
                        final strikeIssued = app["strike_issued"] == true;
                        final appealStatus =
                            (app["strike_appeal_status"] ?? "none").toString();
                        final canAppeal = strikeIssued &&
                            (appealStatus == "eligible" ||
                                appealStatus == "none");
                        final subtitle =
                            status.toString().toLowerCase() == "cancelled" &&
                                    cancelReason.isNotEmpty
                                ? "$location\nReason: $cancelReason"
                                : location.toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text(subtitle),
                            isThreeLine: status.toString().toLowerCase() ==
                                    "cancelled" &&
                                cancelReason.isNotEmpty,
                            onTap: () async {
                              final raw = app["event_id"];
                              final eventId = raw is int
                                  ? raw
                                  : int.tryParse(raw?.toString() ?? "");
                              if (eventId == null) return;
                              await openEventDetails(eventId);
                            },
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Chip(
                                  label: Text(statusLabel(status.toString())
                                      .toUpperCase()),
                                  backgroundColor:
                                      statusColor(status).withOpacity(0.15),
                                  labelStyle:
                                      TextStyle(color: statusColor(status)),
                                ),
                                if (canCancel)
                                  TextButton(
                                    onPressed: isCancelling
                                        ? null
                                        : () => _cancelApplication(app),
                                    style: isWithinLockWindow
                                        ? TextButton.styleFrom(
                                            foregroundColor: Colors.grey,
                                          )
                                        : null,
                                    child: isCancelling
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : Text(
                                            isWithinLockWindow
                                                ? "Cancel (Locked)"
                                                : "Cancel",
                                          ),
                                  ),
                                if (canAppeal)
                                  TextButton(
                                    onPressed: () => _submitStrikeAppeal(app),
                                    child: const Text("Appeal"),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
