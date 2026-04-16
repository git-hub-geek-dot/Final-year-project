import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../utils/ist_date_time.dart';
import '../../widgets/app_background.dart';
import '../../widgets/error_state.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final List<dynamic> _reports = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  String? _errorMessage;

  String _statusFilter = "all";
  String _typeFilter = "all";

  @override
  void initState() {
    super.initState();
    _fetchReports(reset: true);
  }

  Future<void> _fetchReports({bool reset = false}) async {
    if (_loadingMore) return;
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _totalPages = 1;
        _reports.clear();
        _errorMessage = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final data = await ReportService.getMyReports(
        page: _page,
        limit: 20,
        status: _statusFilter,
        type: _typeFilter,
      );
      final items = (data["items"] as List?) ?? [];
      if (!mounted) return;

      setState(() {
        _reports.addAll(items);
        _totalPages = data["totalPages"] ?? 1;
        _loading = false;
        _loadingMore = false;
        _page += 1;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMessage = "Failed to load reports";
      });
    }
  }

  String _formatDate(dynamic raw) => IstDateTime.formatDateTime(raw);

  String _formatReason(dynamic raw) {
    final reason = (raw ?? "").toString().trim();
    if (reason.isEmpty) return "-";
    if (reason.toLowerCase() == "unpaid compensation") {
      return "Unpaid compensation";
    }
    if (reason.toLowerCase() == "attendance reopen request") {
      return "Attendance reopen request";
    }
    return reason;
  }

  String _targetTitle(Map report) {
    final type = report["target_type"]?.toString() ?? "unknown";
    if (type == "user") {
      return "User: ${report["target_user_name"] ?? "Unknown"}";
    }
    if (type == "event") {
      if (_formatReason(report["reason"]) == "Attendance reopen request") {
        return "Attendance reopen: ${report["target_event_title"] ?? "Unknown"}";
      }
      if (_formatReason(report["reason"]) == "Unpaid compensation") {
        return "Payment issue: ${report["target_event_title"] ?? "Unknown"}";
      }
      return "Event: ${report["target_event_title"] ?? "Unknown"}";
    }
    if (type == "chat_message") {
      return "Chat message";
    }
    return "Target";
  }

  String _targetSubtitle(Map report) {
    final type = report["target_type"]?.toString() ?? "unknown";
    if (type == "user") {
      return report["target_user_email"]?.toString() ?? "";
    }
    if (type == "event") {
      final organiser = report["organiser_name"]?.toString() ?? "-";
      return "Organiser: $organiser";
    }
    if (type == "chat_message") {
      final sender = report["message_sender_name"]?.toString() ?? "Unknown";
      final text = report["target_message"]?.toString() ?? "";
      final clipped = text.length > 80 ? "${text.substring(0, 80)}..." : text;
      return "From $sender: $clipped";
    }
    return "";
  }

  String _formatAction(dynamic raw) {
    final action = (raw ?? "").toString().trim().toLowerCase();
    if (action.isEmpty) return "-";
    if (action == "none") return "No action needed";
    if (action == "dismissed") return "Dismissed";
    if (action == "cancel_event") return "Event removed";
    if (action == "reopen_attendance") return "Attendance reopened (24h)";
    if (action.startsWith("strike_")) return "Account strike";
    if (action.startsWith("suspend_")) return "Account suspension";
    return action.replaceAll("_", " ");
  }

  Color _statusColor(String status) {
    switch (status) {
      case "resolved":
        return Colors.green;
      case "dismissed":
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "resolved":
        return "RESOLVED";
      case "dismissed":
        return "DISMISSED";
      default:
        return "PENDING";
    }
  }

  Future<void> _showDetails(Map report) async {
    final status = report["status"]?.toString() ?? "pending";
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_targetTitle(report)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Status: ${_statusLabel(status)}"),
              const Divider(height: 18),
              Text("Reason: ${_formatReason(report["reason"])}"),
              if ((report["details"] ?? "").toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text("Details: ${report["details"]}"),
              ],
              const Divider(height: 18),
              Text("Target: ${_targetTitle(report)}"),
              Text(_targetSubtitle(report)),
              const SizedBox(height: 8),
              Text("Created: ${_formatDate(report["created_at"])}"),
              if (report["resolved_at"] != null)
                Text("Resolved: ${_formatDate(report["resolved_at"])}"),
              if ((report["action_taken"] ?? "").toString().isNotEmpty)
                Text("Action: ${_formatAction(report["action_taken"])}"),
              if ((report["admin_note"] ?? "").toString().isNotEmpty)
                Text("Admin note: ${report["admin_note"]}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchReports(reset: true),
          ),
        ],
      ),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? ErrorState(
                    message: _errorMessage!,
                    onRetry: () => _fetchReports(reset: true),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: _statusFilter,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: "all",
                                    child: Text("All Status"),
                                  ),
                                  DropdownMenuItem(
                                    value: "pending",
                                    child: Text("Pending"),
                                  ),
                                  DropdownMenuItem(
                                    value: "resolved",
                                    child: Text("Resolved"),
                                  ),
                                  DropdownMenuItem(
                                    value: "dismissed",
                                    child: Text("Dismissed"),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _statusFilter = value);
                                  _fetchReports(reset: true);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _typeFilter,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: "all",
                                    child: Text("All Types"),
                                  ),
                                  DropdownMenuItem(
                                    value: "user",
                                    child: Text("User"),
                                  ),
                                  DropdownMenuItem(
                                    value: "event",
                                    child: Text("Event"),
                                  ),
                                  DropdownMenuItem(
                                    value: "chat_message",
                                    child: Text("Chat message"),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _typeFilter = value);
                                  _fetchReports(reset: true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _reports.isEmpty
                            ? const Center(child: Text("No reports found"))
                            : ListView.builder(
                                itemCount: _reports.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _reports.length) {
                                    final canLoadMore = _page <= _totalPages;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: canLoadMore
                                            ? ElevatedButton(
                                                onPressed: _loadingMore
                                                    ? null
                                                    : () => _fetchReports(),
                                                child: _loadingMore
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Text("Load More"),
                                              )
                                            : const Text("No more reports"),
                                      ),
                                    );
                                  }

                                  final report = _reports[index];
                                  final status =
                                      report["status"]?.toString() ?? "pending";

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      onTap: () => _showDetails(report),
                                      title: Text(_targetTitle(report)),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_targetSubtitle(report)),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Reason: ${_formatReason(report["reason"])}",
                                          ),
                                          Text(
                                            "Created: ${_formatDate(report["created_at"])}",
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _statusColor(status).withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
