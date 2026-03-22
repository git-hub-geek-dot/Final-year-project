import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import '../../services/token_service.dart';
import '../../utils/ist_date_time.dart';
import '../../utils/payment_format.dart';
import '../../localization/localization_extensions.dart';

class CompensationStatusScreen extends StatefulWidget {
  const CompensationStatusScreen({super.key});

  @override
  State<CompensationStatusScreen> createState() =>
      _CompensationStatusScreenState();
}

class _CompensationStatusScreenState extends State<CompensationStatusScreen> {
  bool loading = true;
  String? errorMessage;
  List applications = [];
  final Set<int> _reportedApplicationIds = <int>{};
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    fetchCompensationStatus();
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
    if (type != "payment_issue_update") {
      return;
    }

    fetchCompensationStatus();

    final message = (data["message"] ?? "").toString().trim();
    if (message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> fetchCompensationStatus() async {
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

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List filteredApplications;
        if (decoded is Map && decoded["applications"] is List) {
          filteredApplications = decoded["applications"];
        } else if (decoded is List) {
          filteredApplications = decoded;
        } else {
          filteredApplications = [];
        }

        filteredApplications = filteredApplications.where((app) {
          final status = (app["status"] ?? "").toString().toLowerCase();
          return status == "approved" ||
              status == "accepted" ||
              status == "completed";
        }).toList();

        final pendingReportedIds = filteredApplications
            .whereType<Map>()
            .map((app) => Map<String, dynamic>.from(app))
            .where((app) => app["unpaid_compensation_report_pending"] == true)
            .map(_applicationId)
            .whereType<int>()
            .toSet();

        setState(() {
          applications = filteredApplications;
          _reportedApplicationIds
            ..clear()
            ..addAll(pendingReportedIds);
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = context.tr(
            "Error {statusCode}: {message}",
            args: {
              "statusCode": response.statusCode.toString(),
              "message": response.body,
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

  Future<void> _updateStatus(int applicationId, String status) async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final url = Uri.parse(
        "${ApiConfig.baseUrl}/applications/$applicationId/compensation",
      );

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updated = data["application"];
        if (updated != null) {
          setState(() {
            applications = applications.map((app) {
              if (app["id"] == updated["id"]) {
                app["compensation_status"] = updated["compensation_status"];
              }
              return app;
            }).toList();
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("Status updated"))),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                "Failed: {message}",
                args: {"message": response.body},
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Failed to update status"))),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "received":
        return Colors.green;
      case "not_applicable":
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "received":
        return context.tr("Received");
      case "not_applicable":
        return context.tr("Not applicable");
      default:
        return context.tr("Pending");
    }
  }

  String _paymentSubtitle(Map app) {
    final location = (app["location"] ?? "").toString();
    final paymentText = formatPaidPaymentAmount(
      app["payment_amount"],
      app["payment_rate_type"],
    );

    if (paymentText == null) {
      return location;
    }

    if (location.isEmpty) {
      return paymentText;
    }

    return "$location - $paymentText";
  }

  int? _applicationId(Map app) {
    final raw = app["id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? "");
  }

  int? _eventId(Map app) {
    final raw = app["event_id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? "");
  }

  bool _isReportEligible(Map app) {
    final eventType = (app["event_type"] ?? "unpaid").toString().toLowerCase();
    final compensationStatus =
        (app["compensation_status"] ?? "pending").toString().toLowerCase();
    final applicationStatus =
        (app["status"] ?? "pending").toString().toLowerCase();
    final hasPendingReport = _hasPendingUnpaidReport(app);
    final clearanceDateRaw = app["payment_clearance_date"]?.toString();
    final clearanceDate = IstDateTime.tryParse(clearanceDateRaw);

    if (eventType != "paid") return false;
    if (compensationStatus != "pending") return false;
    if (hasPendingReport) return false;
    if (!["approved", "accepted", "completed"].contains(applicationStatus)) {
      return false;
    }
    if (clearanceDate == null) return false;

    final clearanceDay = IstDateTime.startOfDay(clearanceDate);
    final today = IstDateTime.startOfDay(IstDateTime.now());
    return !clearanceDay.isAfter(today);
  }

  bool _hasPendingUnpaidReport(Map app) {
    final applicationId = _applicationId(app);
    if (applicationId != null && _reportedApplicationIds.contains(applicationId)) {
      return true;
    }

    return app["unpaid_compensation_report_pending"] == true;
  }

  String? _paymentStatusNote(Map app) {
    final eventType = (app["event_type"] ?? "unpaid").toString().toLowerCase();
    if (eventType != "paid") return null;

    final compensationStatus =
        (app["compensation_status"] ?? "pending").toString().toLowerCase();
    final applicationStatus =
        (app["status"] ?? "pending").toString().toLowerCase();
    final hasPendingReport = _hasPendingUnpaidReport(app);
    final clearanceDateRaw = app["payment_clearance_date"]?.toString();
    final clearanceDate = IstDateTime.tryParse(clearanceDateRaw);
    final today = IstDateTime.startOfDay(IstDateTime.now());

    if (compensationStatus == "received") {
      return context.tr("Payment marked as received.");
    }

    if (hasPendingReport) {
      return context.tr("Unpaid payment report submitted. Admin review pending.");
    }

    if (!["approved", "accepted", "completed"].contains(applicationStatus)) {
      return null;
    }

    if (compensationStatus != "pending") {
      return null;
    }

    if (clearanceDate == null) {
      return context.tr("Payment clearance date is not available yet.");
    }

    final clearanceDay = IstDateTime.startOfDay(clearanceDate);
    if (clearanceDay.isAfter(today)) {
      return context.tr(
        "You can report unpaid payment after {date}.",
        args: {"date": IstDateTime.formatDate(clearanceDate)},
      );
    }

    return context.tr("Payment is still pending after clearance date.");
  }

  Future<void> _reportUnpaidPayment(Map app) async {
    final applicationId = _applicationId(app);
    final eventId = _eventId(app);
    if (applicationId == null || eventId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Payment report details are not available."),
          ),
        ),
      );
      return;
    }

    if (_reportedApplicationIds.contains(applicationId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("This unpaid payment report was already submitted."),
          ),
        ),
      );
      return;
    }

    final detailsController = TextEditingController();
    String? detailsError;

    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            return AlertDialog(
              title: Text(context.tr("Report Unpaid Payment")),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        "This will create an admin report for unpaid compensation on {event}.",
                        args: {
                          "event": (app["title"] ?? context.tr("this event"))
                              .toString(),
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      onChanged: (_) {
                        if (detailsError != null) {
                          setLocalState(() => detailsError = null);
                        }
                      },
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: context.tr("Details"),
                        hintText: context.tr(
                          "Add any payment issue details for admin review.",
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
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.tr("Cancel")),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (detailsController.text.trim().isEmpty) {
                      setLocalState(() {
                        detailsError = context.tr(
                          "Please add a short note for admin review.",
                        );
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Text(context.tr("Submit Report")),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      detailsController.dispose();
      return;
    }

    try {
      final title =
          (app["title"] ?? context.tr("Unknown event")).toString();
      final paymentText = formatPaidPaymentAmount(
            app["payment_amount"],
            app["payment_rate_type"],
          ) ??
          context.tr("Paid event");
      final clearanceText = app["payment_clearance_date"]?.toString();
      final volunteerNote = detailsController.text.trim();
      final autoDetails = [
        "Payment issue for event: $title",
        "Expected payment: $paymentText",
        if (clearanceText != null && clearanceText.isNotEmpty)
          "Payment clearance date: ${IstDateTime.formatDate(clearanceText)}",
        "Volunteer note: $volunteerNote",
      ].join("\n");

      await ReportService.submitReport(
        targetType: "event",
        targetId: eventId,
        reason: "Unpaid compensation",
        details: autoDetails,
      );

      if (!mounted) return;
      setState(() {
        _reportedApplicationIds.add(applicationId);
        applications = applications.map((app) {
          if (_applicationId(app) == applicationId) {
            final updated = Map<String, dynamic>.from(app);
            updated["unpaid_compensation_report_pending"] = true;
            return updated;
          }
          return app;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Unpaid payment report submitted for admin review."),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "Failed to submit report: {error}",
              args: {"error": e.toString()},
            ),
          ),
        ),
      );
    } finally {
      detailsController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Payment Status"))),
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
                  ? Center(
                      child: Text(context.tr("No approved events yet")),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final app = applications[index];
                        final title =
                            app["title"] ?? context.tr("Unknown Event");
                        final location = (app["location"] ?? "").toString();
                        final eventType =
                            (app["event_type"] ?? "unpaid").toString();
                        final status =
                            (app["compensation_status"] ?? "pending")
                                .toString();
                        final canReportUnpaid = _isReportEligible(app);
                        final alreadyReported = _hasPendingUnpaidReport(app);
                        final paymentStatusNote = _paymentStatusNote(app);
                        final showReportAction =
                            canReportUnpaid || alreadyReported;

                        final isPaid = eventType.toLowerCase() == "paid";
                        final subtitle = isPaid
                            ? _paymentSubtitle(app)
                            : location;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(title),
                                subtitle: Text(subtitle),
                                trailing: Chip(
                                  label: Text(_statusLabel(status)),
                                  backgroundColor:
                                      _statusColor(status).withOpacity(0.15),
                                  labelStyle:
                                      TextStyle(color: _statusColor(status)),
                                ),
                                onTap: !isPaid
                                    ? null
                                    : () async {
                                        final choice =
                                            await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (_) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green,
                                                  ),
                                                  title: Text(
                                                    context.tr("Received"),
                                                  ),
                                                  onTap: () => Navigator.pop(
                                                    context,
                                                    "received",
                                                  ),
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.hourglass_top,
                                                    color: Colors.orange,
                                                  ),
                                                  title: Text(
                                                    context.tr("Pending"),
                                                  ),
                                                  onTap: () => Navigator.pop(
                                                    context,
                                                    "pending",
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );

                                        if (choice != null) {
                                          final appId = app["id"];
                                          if (appId != null) {
                                            await _updateStatus(appId, choice);
                                          }
                                        }
                                      },
                              ),
                              if ((paymentStatusNote != null && isPaid) ||
                                  canReportUnpaid ||
                                  alreadyReported)
                                const Divider(height: 1),
                              if ((paymentStatusNote != null && isPaid) ||
                                  canReportUnpaid ||
                                  alreadyReported)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          paymentStatusNote ?? "",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: alreadyReported
                                                ? Colors.green.shade700
                                                : canReportUnpaid
                                                    ? Colors.redAccent
                                                    : Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (showReportAction)
                                        TextButton.icon(
                                          onPressed: alreadyReported
                                              ? null
                                              : () => _reportUnpaidPayment(app),
                                          icon: const Icon(Icons.report_outlined),
                                          label: Text(
                                            alreadyReported
                                                ? context.tr("Reported")
                                                : context.tr(
                                                    "Report unpaid payment",
                                                  ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
