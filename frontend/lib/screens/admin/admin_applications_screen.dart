import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_background.dart';
import 'package:frontend/widgets/error_state.dart';

import '../../services/admin_service.dart';
import '../../utils/ist_date_time.dart';

class AdminApplicationsScreen extends StatefulWidget {
  final int? eventId;

  const AdminApplicationsScreen({super.key, this.eventId});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  final List<dynamic> apps = [];
  bool loading = true;
  String? errorMessage;
  String statusFilter = "all";
  String search = "";
  String sortField = "applied_at";
  bool sortAsc = false;

  @override
  void initState() {
    super.initState();
    _fetchApplications(reset: true);
  }

  Future<void> _fetchApplications({bool reset = false}) async {
    if (reset) {
      setState(() {
        loading = true;
        apps.clear();
        errorMessage = null;
      });
    }

    try {
      final allItems = <dynamic>[];
      int currentPage = 1;
      int lastPage = 1;

      do {
        final data = await AdminService.getAllApplications(
          page: currentPage,
          limit: 20,
          eventId: widget.eventId,
        );
        final items = (data["items"] as List?) ?? [];
        lastPage = data["totalPages"] ?? currentPage;
        allItems.addAll(items);
        currentPage += 1;
      } while (currentPage <= lastPage);

      if (!mounted) return;
      setState(() {
        apps
          ..clear()
          ..addAll(allItems);
        loading = false;
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        if (reset) {
          errorMessage = "Failed to load applications";
        }
      });
    }
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    String? localError;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text("Cancel Application"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the reason shown to the volunteer."),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: "Reason",
                  errorText: localError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
            TextButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setLocalState(() {
                    localError = "Reason is required";
                  });
                  return;
                }
                Navigator.pop(ctx, reason);
              },
              child: const Text("Cancel Application"),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return result;
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "accepted":
        return Colors.green;
      case "no_show":
        return Colors.deepOrange;
      case "rejected":
      case "cancelled":
        return Colors.red;
      case "pending":
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
      case "no_show":
        return "No-show";
      case "pending":
        return "Pending";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventId != null ? "Event Applications" : "All Applications",
        ),
      ),
      body: AppBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? ErrorState(
                    message: errorMessage!,
                    onRetry: () => _fetchApplications(reset: true),
                  )
                : Builder(
                    builder: (context) {
                      final filtered = apps.where((a) {
                        final matchStatus = statusFilter == "all" ||
                            a["status"] == statusFilter;
                        final matchEvent = widget.eventId == null ||
                            _toInt(a["event_id"]) == widget.eventId;

                        final searchText = search.toLowerCase();
                        final volunteerName = (a["volunteer_name"] ?? "")
                            .toString()
                            .toLowerCase();
                        final volunteerEmail = (a["volunteer_email"] ?? "")
                            .toString()
                            .toLowerCase();
                        final eventTitle =
                            (a["event_title"] ?? "").toString().toLowerCase();
                        final organiserName = (a["organiser_name"] ?? "")
                            .toString()
                            .toLowerCase();

                        final matchSearch = searchText.isEmpty ||
                            volunteerName.contains(searchText) ||
                            volunteerEmail.contains(searchText) ||
                            eventTitle.contains(searchText) ||
                            organiserName.contains(searchText);

                        return matchStatus && matchSearch && matchEvent;
                      }).toList()
                        ..sort((a, b) => _compareApps(a, b));

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Search volunteer or event",
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (v) => setState(() => search = v),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                DropdownButton<String>(
                                  value: statusFilter,
                                  items: const [
                                    DropdownMenuItem(
                                      value: "all",
                                      child: Text("All Applications"),
                                    ),
                                    DropdownMenuItem(
                                      value: "pending",
                                      child: Text("Pending"),
                                    ),
                                    DropdownMenuItem(
                                      value: "approved",
                                      child: Text("Approved"),
                                    ),
                                    DropdownMenuItem(
                                      value: "rejected",
                                      child: Text("Rejected"),
                                    ),
                                    DropdownMenuItem(
                                      value: "cancelled",
                                      child: Text("Cancelled"),
                                    ),
                                    DropdownMenuItem(
                                      value: "no_show",
                                      child: Text("No-show"),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => statusFilter = v!),
                                ),
                                const SizedBox(width: 16),
                                DropdownButton<String>(
                                  value: sortField,
                                  items: const [
                                    DropdownMenuItem(
                                      value: "applied_at",
                                      child: Text("Applied"),
                                    ),
                                    DropdownMenuItem(
                                      value: "event_date",
                                      child: Text("Event Date"),
                                    ),
                                    DropdownMenuItem(
                                      value: "status",
                                      child: Text("Status"),
                                    ),
                                    DropdownMenuItem(
                                      value: "volunteer_name",
                                      child: Text("Volunteer"),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => sortField = v!),
                                ),
                                IconButton(
                                  icon: Icon(
                                    sortAsc
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                  ),
                                  onPressed: () =>
                                      setState(() => sortAsc = !sortAsc),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Text(_emptyMessage()),
                                  )
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final app = Map<String, dynamic>.from(
                                        filtered[i] as Map,
                                      );
                                      return _buildApplicationCard(
                                          context, app);
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> app) {
    final volunteerName = app["volunteer_name"] ?? "-";
    final volunteerEmail = app["volunteer_email"] ?? "-";
    final volunteerCity = app["volunteer_city"] ?? "-";
    final eventTitle = app["event_title"] ?? "-";
    final organiserName = app["organiser_name"] ?? "-";
    final eventDate = _fmtDate(app["event_date"]);
    final eventCreatedAt = _fmtDateTime(app["event_created_at"]);
    final appliedAt = _fmtDateTime(app["applied_at"]);
    final status = app["status"] ?? "-";
    final statusText = statusLabel(status.toString());
    final cancelReason = (app["admin_cancel_reason"] ?? "").toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Application Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Event", eventTitle),
              _detailRow("Organiser", organiserName),
              _detailRow("Event Start", eventDate),
              _detailRow("Event Created", eventCreatedAt),
              const SizedBox(height: 8),
              _detailRow("Volunteer", volunteerName),
              _detailRow("Email", volunteerEmail),
              _detailRow("City", volunteerCity),
              const SizedBox(height: 8),
              _detailRow("Status", statusText),
              _detailRow("Applied", appliedAt),
              if (status == "cancelled" && cancelReason.isNotEmpty)
                _detailRow("Reason", cancelReason),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _emptyMessage() {
    switch (statusFilter) {
      case "pending":
        return "No pending applications found";
      case "approved":
        return "No approved applications found";
      case "rejected":
        return "No rejected applications found";
      case "cancelled":
        return "No cancelled applications found";
      case "no_show":
        return "No no-show applications found";
      case "all":
      default:
        return "No applications found";
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "accepted":
        return Icons.check_circle;
      case "rejected":
        return Icons.block;
      case "cancelled":
        return Icons.cancel;
      case "no_show":
        return Icons.person_off;
      case "pending":
      default:
        return Icons.hourglass_top;
    }
  }

  String _initialLetter(String text) {
    final value = text.trim();
    if (value.isEmpty) return "?";
    return value[0].toUpperCase();
  }

  String _appliedAgo(dynamic value) {
    if (value == null) return "Applied recently";
    final parsed = IstDateTime.tryParse(value);
    if (parsed == null) return "Applied recently";

    final diff = IstDateTime.now().difference(parsed);
    if (diff.inDays > 0) return "Applied ${diff.inDays}d ago";
    if (diff.inHours > 0) return "Applied ${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "Applied ${diff.inMinutes}m ago";
    return "Applied just now";
  }

  Future<void> _cancelApplication(
    BuildContext context,
    Map<String, dynamic> app,
  ) async {
    final reason = await _askCancelReason();
    if (reason == null) return;

    final rawId = app["id"];
    final appId = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (appId == null) return;

    try {
      await AdminService.cancelApplication(appId, reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application cancelled")),
      );
      _fetchApplications(reset: true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst("Exception: ", ""),
          ),
        ),
      );
    }
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            statusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    Map<String, dynamic> app,
  ) {
    final statusRaw = (app["status"] ?? "").toString().toLowerCase();
    final status = statusRaw.isEmpty ? "pending" : statusRaw;
    final isCancelled = status == "cancelled";
    final cancelReason = (app["admin_cancel_reason"] ?? "").toString().trim();

    final eventTitle = (app["event_title"] ?? "-").toString();
    final volunteerName = (app["volunteer_name"] ?? "-").toString();
    final volunteerEmail = (app["volunteer_email"] ?? "-").toString();
    final organiserName = (app["organiser_name"] ?? "-").toString();
    final eventDate = _fmtDate(app["event_date"]);
    final appliedAgo = _appliedAgo(app["applied_at"]);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetails(context, app),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor(status).withAlpha(30),
                    child: Text(
                      _initialLetter(volunteerName),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          volunteerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          volunteerEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusChip(status),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                children: [
                  _metaChip(Icons.calendar_today, "Event: $eventDate"),
                  _metaChip(Icons.business, "Organiser: $organiserName"),
                  _metaChip(Icons.schedule, appliedAgo),
                ],
              ),
              if (isCancelled && cancelReason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Cancellation reason: $cancelReason",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showDetails(context, app),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text("View details"),
                  ),
                  const Spacer(),
                  if (!isCancelled)
                    OutlinedButton.icon(
                      onPressed: () => _cancelApplication(context, app),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text("Cancel"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic value) {
    return IstDateTime.formatDate(value);
  }

  String _fmtDateTime(dynamic value) {
    return IstDateTime.formatDateTime(value);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int _compareApps(Map a, Map b) {
    int result;
    switch (sortField) {
      case "volunteer_name":
        result = (a["volunteer_name"] ?? "")
            .toString()
            .toLowerCase()
            .compareTo((b["volunteer_name"] ?? "").toString().toLowerCase());
        break;
      case "status":
        result = (a["status"] ?? "")
            .toString()
            .compareTo((b["status"] ?? "").toString());
        break;
      case "event_date":
        final aDate = IstDateTime.tryParse((a["event_date"] ?? "").toString());
        final bDate = IstDateTime.tryParse((b["event_date"] ?? "").toString());
        result = (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
        break;
      case "applied_at":
      default:
        final aDate = IstDateTime.tryParse((a["applied_at"] ?? "").toString());
        final bDate = IstDateTime.tryParse((b["applied_at"] ?? "").toString());
        result = (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
        break;
    }

    return sortAsc ? result : -result;
  }
}
