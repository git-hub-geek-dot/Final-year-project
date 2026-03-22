import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'package:frontend/widgets/error_state.dart';

import '../../services/admin_service.dart';
import '../../utils/ist_date_time.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final List<dynamic> _reports = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  String? _errorMessage;

  String _statusFilter = "pending";
  String _typeFilter = "all";
  String _search = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchReports(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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
      final data = await AdminService.getReports(
        page: _page,
        limit: 20,
        status: _statusFilter,
        type: _typeFilter,
        search: _search,
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _search = value.trim());
      _fetchReports(reset: true);
    });
  }

  String _formatDate(dynamic raw) {
    return IstDateTime.formatDateTime(raw);
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

  String _formatActionTaken(dynamic raw) {
    final action = (raw ?? "").toString().trim().toLowerCase();
    if (action.isEmpty) return "-";
    if (action == "none") return "Resolved without action";
    if (action == "dismissed") return "Dismissed";
    if (action == "cancel_event") return "Event removed";
    if (action.startsWith("strike_")) {
      final suffix = action.substring("strike_".length).replaceAll("_", " ");
      return "Strike: $suffix";
    }
    if (action.startsWith("suspend_") && action.endsWith("_days")) {
      final days = action
          .substring("suspend_".length, action.length - "_days".length)
          .replaceAll("_", " ");
      return "Suspended user ($days days)";
    }
    return action.replaceAll("_", " ");
  }

  String _formatReason(dynamic raw) {
    final reason = (raw ?? "").toString().trim();
    if (reason.isEmpty) return "-";
    if (reason.toLowerCase() == "unpaid compensation") {
      return "Unpaid compensation";
    }
    return reason;
  }

  bool _isUnpaidCompensationReport(Map report) {
    final reason = (report["reason"] ?? "").toString().trim().toLowerCase();
    return reason == "unpaid compensation";
  }

  String _targetTitle(Map report) {
    final type = report["target_type"]?.toString() ?? "unknown";
    if (type == "user") {
      return "User: ${report["target_user_name"] ?? "Unknown"}";
    }
    if (type == "event") {
      if (_isUnpaidCompensationReport(report)) {
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
      if (_isUnpaidCompensationReport(report)) {
        return "Organiser: $organiser  |  Volunteer reported unpaid payment";
      }
      return "Organiser: $organiser";
    }
    if (type == "chat_message") {
      final sender = report["message_sender_name"]?.toString() ?? "Unknown";
      final text = report["target_message"]?.toString() ?? "";
      final clipped = text.length > 60 ? "${text.substring(0, 60)}..." : text;
      return "From $sender: $clipped";
    }
    return "";
  }

  String? _actionTargetLabel(Map report) {
    final type = report["target_type"]?.toString() ?? "unknown";
    if (type == "event") {
      final organiser = report["organiser_name"]?.toString().trim() ?? "";
      return organiser.isEmpty ? "Action target: organiser" : "Action target: organiser $organiser";
    }
    if (type == "chat_message") {
      final sender = report["message_sender_name"]?.toString().trim() ?? "";
      return sender.isEmpty ? "Action target: message sender" : "Action target: message sender $sender";
    }
    if (type == "user") {
      final user = report["target_user_name"]?.toString().trim() ?? "";
      return user.isEmpty ? "Action target: reported user" : "Action target: reported user $user";
    }
    return null;
  }

  String _strikeActionLabel(Map report) {
    final type = report["target_type"]?.toString() ?? "unknown";
    if (type == "event") return "Strike organiser";
    if (type == "chat_message") return "Strike sender";
    return "Strike user";
  }

  String _suspendActionLabel(Map report) {
    final type = report["target_type"]?.toString() ?? "unknown";
    if (type == "event") return "Suspend organiser";
    if (type == "chat_message") return "Suspend sender";
    return "Suspend user";
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    int maxLength = 500,
    bool isRequired = true,
  }) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (isRequired && text.isEmpty) {
                  setState(() => error = "Required");
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _promptSuspend() async {
    final daysController = TextEditingController();
    final reasonController = TextEditingController();
    String? error;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Suspend user"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Days",
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: "Reason",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final days = int.tryParse(daysController.text.trim());
                final reason = reasonController.text.trim();
                if (days == null || days < 1) {
                  setState(() => error = "Enter valid days");
                  return;
                }
                if (reason.isEmpty) {
                  setState(() => error = "Reason is required");
                  return;
                }
                Navigator.pop(ctx, {"days": days, "reason": reason});
              },
              child: const Text("Suspend"),
            ),
          ],
        ),
      ),
    );

    daysController.dispose();
    reasonController.dispose();
    return result;
  }

  Future<void> _resolveReport({
    required int reportId,
    required String action,
    String? note,
    String? strikeReason,
    int? suspendDays,
    String? suspendReason,
    String? cancelReason,
  }) async {
    try {
      await AdminService.resolveReport(
        reportId: reportId,
        action: action,
        note: note ?? "",
        strikeReason: strikeReason,
        suspendDays: suspendDays,
        suspendReason: suspendReason,
        cancelReason: cancelReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report updated")),
      );
      _fetchReports(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Action failed: $e")),
      );
    }
  }

  Future<void> _dismissReport(int reportId) async {
    final note = await _promptText(
      title: "Dismiss report",
      hint: "Optional note",
      maxLength: 500,
      isRequired: false,
    );

    if (note == null) return;

    try {
      await AdminService.dismissReport(reportId: reportId, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report dismissed")),
      );
      _fetchReports(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dismiss failed: $e")),
      );
    }
  }

  Future<String?> _promptAdminNote(String title) {
    return _promptText(
      title: title,
      hint: "Internal admin note (optional)",
      maxLength: 500,
      isRequired: false,
    );
  }

  Future<void> _showDetails(Map report) async {
    final status = report["status"]?.toString() ?? "pending";
    final canAct = status == "pending";
    final actionUserId = report["action_user_id"];
    final actionEventId = report["action_event_id"];
    final actionTargetLabel = _actionTargetLabel(report);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_targetTitle(report)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Status: $status"),
              const SizedBox(height: 6),
              Text("Reported by: ${report["reporter_name"] ?? "-"}"),
              Text("Reporter email: ${report["reporter_email"] ?? "-"}"),
              const Divider(height: 18),
              Text("Reason: ${_formatReason(report["reason"])}"),
              if ((report["details"] ?? "").toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text("Details: ${report["details"]}"),
              ],
              const Divider(height: 18),
              Text("Target: ${_targetTitle(report)}"),
              Text(_targetSubtitle(report)),
              if (actionTargetLabel != null) ...[
                const SizedBox(height: 6),
                Text(actionTargetLabel),
              ],
              const SizedBox(height: 8),
              Text("Created: ${_formatDate(report["created_at"])}"),
              if (report["resolved_at"] != null)
                Text("Resolved: ${_formatDate(report["resolved_at"])}"),
              if ((report["action_taken"] ?? "").toString().isNotEmpty)
                Text(
                  "Action: ${_formatActionTaken(report["action_taken"])}",
                ),
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
          if (canAct)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final note = await _promptAdminNote("Resolve report");
                if (note == null) return;
                _resolveReport(
                  reportId: report["id"],
                  action: "none",
                  note: note,
                );
              },
              child: const Text("Resolve without action"),
            ),
          if (canAct)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _dismissReport(report["id"]);
              },
              child: const Text("Dismiss"),
            ),
          if (canAct && actionUserId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final reason = await _promptText(
                  title: "Add strike",
                  hint: "Strike reason",
                  maxLength: 500,
                );
                if (reason == null) return;
                final note = await _promptAdminNote("Add admin note");
                if (note == null) return;
                _resolveReport(
                  reportId: report["id"],
                  action: "strike",
                  note: note,
                  strikeReason: reason,
                );
              },
              child: Text(_strikeActionLabel(report)),
            ),
          if (canAct && actionUserId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final data = await _promptSuspend();
                if (data == null) return;
                final note = await _promptAdminNote("Add admin note");
                if (note == null) return;
                _resolveReport(
                  reportId: report["id"],
                  action: "suspend",
                  note: note,
                  suspendDays: data["days"] as int,
                  suspendReason: data["reason"] as String,
                );
              },
              child: Text(_suspendActionLabel(report)),
            ),
          if (canAct && actionEventId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final reason = await _promptText(
                  title: "Remove event",
                  hint: "Reason shown to organiser (optional)",
                  maxLength: 500,
                  isRequired: false,
                );
                if (reason == null) return;
                final note = await _promptAdminNote("Add admin note");
                if (note == null) return;
                _resolveReport(
                  reportId: report["id"],
                  action: "cancel_event",
                  note: note,
                  cancelReason: reason,
                );
              },
              child: const Text("Remove event"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
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
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search reports",
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: _statusFilter,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: "pending", child: Text("Pending")),
                                  DropdownMenuItem(
                                      value: "resolved",
                                      child: Text("Resolved")),
                                  DropdownMenuItem(
                                      value: "dismissed",
                                      child: Text("Dismissed")),
                                  DropdownMenuItem(
                                      value: "all", child: Text("All")),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _statusFilter = v);
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
                                      value: "all", child: Text("All Types")),
                                  DropdownMenuItem(
                                      value: "user", child: Text("User")),
                                  DropdownMenuItem(
                                      value: "event", child: Text("Event")),
                                  DropdownMenuItem(
                                      value: "chat_message",
                                      child: Text("Chat message")),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _typeFilter = v);
                                  _fetchReports(reset: true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                          vertical: 12),
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
                                                                strokeWidth: 2),
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
                                        horizontal: 12, vertical: 6),
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
                                            "Reported by: ${report["reporter_name"] ?? "-"}",
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
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
