import 'package:flutter/material.dart';

import '../../services/notification_api_service.dart';
import '../../utils/ist_date_time.dart';

class EventAnnouncementsScreen extends StatefulWidget {
  final int eventId;
  final String eventTitle;

  const EventAnnouncementsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventAnnouncementsScreen> createState() =>
      _EventAnnouncementsScreenState();
}

class _EventAnnouncementsScreenState extends State<EventAnnouncementsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final response = await NotificationApiService.fetchNotifications(
        page: 1,
        limit: 100,
      );
      final rows = (response["items"] as List?) ?? [];

      final filtered = rows
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .where((row) {
        final data = (row["data"] is Map)
            ? (row["data"] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final type = (data["type"] ?? "").toString();
        final rawEventId = data["eventId"] ?? data["event_id"];
        final eventId = int.tryParse(rawEventId?.toString() ?? "");
        return type == "event_announcement" && eventId == widget.eventId;
      }).toList();

      setState(() {
        items = filtered;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return "";
    final dt = IstDateTime.tryParse(raw);
    if (dt == null) return "";
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$y-$m-$d $hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Announcements"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text("Failed to load announcements\n$error"))
              : items.isEmpty
                  ? Center(
                      child: Text(
                        "No announcements for ${widget.eventTitle}",
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final row = items[index];
                        final title =
                            (row["title"] ?? "Announcement").toString();
                        final body = (row["body"] ?? "").toString();
                        final createdAt =
                            _formatTime(row["created_at"]?.toString());

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (createdAt.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  createdAt,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(body),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
