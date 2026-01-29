import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:frontend/widgets/app_background.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  final List<dynamic> apps = [];
  bool loading = true;
  bool loadingMore = false;
  int page = 1;
  int totalPages = 1;
  String statusFilter = "all";
  String search = "";

  @override
  void initState() {
    super.initState();
    _fetchApplications(reset: true);
  }

  Future<void> _fetchApplications({bool reset = false}) async {
    if (loadingMore) return;
    if (reset) {
      setState(() {
        loading = true;
        page = 1;
        totalPages = 1;
        apps.clear();
      });
    } else {
      setState(() => loadingMore = true);
    }

    try {
      final data = await AdminService.getAllApplications(page: page, limit: 20);
      final items = (data["items"] as List?) ?? [];
      setState(() {
        apps.addAll(items);
        totalPages = data["totalPages"] ?? 1;
        loading = false;
        loadingMore = false;
        page += 1;
      });
    } catch (_) {
      setState(() {
        loading = false;
        loadingMore = false;
      });
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "accepted":
      case "approved":
        return Colors.green;
      case "rejected":
      case "cancelled":
        return Colors.red;
      case "pending":
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
      ),
      body: AppBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (context) {
                  final filtered = apps.where((a) {
              final matchStatus =
                  statusFilter == "all" || a["status"] == statusFilter;

              final searchText = search.toLowerCase();
              final volunteerName =
                  (a["volunteer_name"] ?? "").toString().toLowerCase();
              final volunteerEmail =
                  (a["volunteer_email"] ?? "").toString().toLowerCase();
              final eventTitle =
                  (a["event_title"] ?? "").toString().toLowerCase();
              final organiserName =
                  (a["organiser_name"] ?? "").toString().toLowerCase();

              final matchSearch = searchText.isEmpty ||
                  volunteerName.contains(searchText) ||
                  volunteerEmail.contains(searchText) ||
                  eventTitle.contains(searchText) ||
                  organiserName.contains(searchText);

              return matchStatus && matchSearch;
            }).toList();

                  return Column(
                    children: [
                      // 🔍 Search
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

                      // 🔽 Status filter
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: DropdownButton<String>(
                          value: statusFilter,
                          items: const [
                            DropdownMenuItem(
                                value: "all", child: Text("All Applications")),
                            DropdownMenuItem(
                                value: "pending", child: Text("Pending")),
                            DropdownMenuItem(
                                value: "accepted", child: Text("Accepted")),
                            DropdownMenuItem(
                                value: "rejected", child: Text("Rejected")),
                            DropdownMenuItem(
                                value: "approved", child: Text("Approved")),
                            DropdownMenuItem(
                                value: "cancelled", child: Text("Cancelled")),
                          ],
                          onChanged: (v) => setState(() => statusFilter = v!),
                        ),
                      ),

                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text("No applications found"))
                            : ListView.builder(
                                itemCount: filtered.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == filtered.length) {
                                    final canLoadMore = page <= totalPages;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: canLoadMore
                                            ? ElevatedButton(
                                                onPressed: loadingMore
                                                    ? null
                                                    : () => _fetchApplications(),
                                                child: loadingMore
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Text("Load More"),
                                              )
                                            : const Text("No more applications"),
                                      ),
                                    );
                                  }

                                  final app = filtered[i];
                                  final isCancelled =
                                      app["status"] == "cancelled";
                                  final eventDate = _fmtDate(app["event_date"]);
                                  final organiserName =
                                      app["organiser_name"] ?? "-";

                                  return Card(
                                    child: ListTile(
                                      title: Text(app["event_title"]),
                                      subtitle: Text(
                                        "${app["volunteer_name"]} • ${app["status"]}\nOrganiser: $organiserName • Date: $eventDate",
                                      ),
                                      isThreeLine: true,
                                      onTap: () => _showDetails(context, app),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Status badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor(app["status"]),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              app["status"],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),

                                          // ❌ Cancel button (only if not cancelled)
                                          if (!isCancelled)
                                            IconButton(
                                              icon: const Icon(Icons.cancel,
                                                  color: Colors.red),
                                              onPressed: () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                        "Cancel Application"),
                                                    content: const Text(
                                                        "Are you sure you want to cancel this application?"),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx, false),
                                                        child: const Text("No"),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx, true),
                                                        child: const Text("Yes"),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  await AdminService
                                                      .cancelApplication(
                                                          app["id"]);
                                                  _fetchApplications(reset: true);
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Application Details"),
        content: Column(
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
            _detailRow("Status", status),
            _detailRow("Applied", appliedAt),
          ],
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

  String _fmtDate(dynamic value) {
    if (value == null) return "-";
    final text = value.toString();
    if (text.isEmpty) return "-";
    return text.split("T")[0];
  }

  String _fmtDateTime(dynamic value) {
    if (value == null) return "-";
    final text = value.toString();
    if (text.isEmpty) return "-";
    return text.replaceAll("T", " ").split(".")[0];
  }
}
