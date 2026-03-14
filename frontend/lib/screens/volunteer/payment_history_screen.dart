import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/report_service.dart';
import '../../services/token_service.dart';
import '../../utils/ist_date_time.dart';
import '../../utils/payment_format.dart';

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

  @override
  void initState() {
    super.initState();
    fetchCompensationStatus();
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

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["applications"] is List) {
          applications = decoded["applications"];
        } else if (decoded is List) {
          applications = decoded;
        } else {
          applications = [];
        }

        applications = applications.where((app) {
          final status = (app["status"] ?? "").toString().toLowerCase();
          return status == "approved" ||
              status == "accepted" ||
              status == "completed";
        }).toList();

        setState(() => loading = false);
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
          const SnackBar(content: Text("Status updated")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update status")),
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
        return "Received";
      case "not_applicable":
        return "Not applicable";
      default:
        return "Pending";
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
    final clearanceDateRaw = app["payment_clearance_date"]?.toString();
    final clearanceDate = IstDateTime.tryParse(clearanceDateRaw);

    if (eventType != "paid") return false;
    if (compensationStatus != "pending") return false;
    if (!["approved", "accepted", "completed"].contains(applicationStatus)) {
      return false;
    }
    if (clearanceDate == null) return false;

    final clearanceDay = IstDateTime.startOfDay(clearanceDate);
    final today = IstDateTime.startOfDay(IstDateTime.now());
    return !clearanceDay.isAfter(today);
  }

  Future<void> _reportUnpaidPayment(Map app) async {
    final applicationId = _applicationId(app);
    final eventId = _eventId(app);
    if (applicationId == null || eventId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment report details are not available.")),
      );
      return;
    }

    if (_reportedApplicationIds.contains(applicationId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This unpaid payment report was already submitted.")),
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
              title: const Text("Report Unpaid Payment"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This will create an admin report for unpaid compensation on ${(app["title"] ?? "this event").toString()}.",
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
                        labelText: "Details",
                        hintText: "Add any payment issue details for admin review.",
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
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (detailsController.text.trim().isEmpty) {
                      setLocalState(() {
                        detailsError = "Please add a short note for admin review.";
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text("Submit Report"),
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
      final title = (app["title"] ?? "Unknown event").toString();
      final paymentText = formatPaidPaymentAmount(
            app["payment_amount"],
            app["payment_rate_type"],
          ) ??
          "Paid event";
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unpaid payment report submitted for admin review."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit report: $e")),
      );
    } finally {
      detailsController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Status")),
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
                  ? const Center(
                      child: Text("No approved events yet"),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final app = applications[index];
                        final title = app["title"] ?? "Unknown Event";
                        final location = (app["location"] ?? "").toString();
                        final eventType =
                            (app["event_type"] ?? "unpaid").toString();
                        final status =
                            (app["compensation_status"] ?? "pending")
                                .toString();
                        final canReportUnpaid = _isReportEligible(app);
                        final alreadyReported = _reportedApplicationIds
                            .contains(_applicationId(app));

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
                                                  title: const Text("Received"),
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
                                                  title: const Text("Pending"),
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
                              if (canReportUnpaid || alreadyReported)
                                const Divider(height: 1),
                              if (canReportUnpaid || alreadyReported)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          alreadyReported
                                              ? "Unpaid payment report submitted."
                                              : "Payment is still pending after clearance date.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: alreadyReported
                                                ? Colors.green.shade700
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: alreadyReported
                                            ? null
                                            : () => _reportUnpaidPayment(app),
                                        icon: const Icon(Icons.report_outlined),
                                        label: Text(
                                          alreadyReported
                                              ? "Reported"
                                              : "Report unpaid payment",
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
