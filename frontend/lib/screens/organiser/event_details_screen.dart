import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'review_application_screen.dart';
import 'edit_event_screen.dart';
import '../../services/event_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final Map event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool loadingStats = true;

  int applied = 0;
  int approved = 0;
  int pending = 0;
  int rejected = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    try {
      final list =
          await EventService.fetchApplications(widget.event["id"]);

      int a = list.length;
      int ap = 0, p = 0, r = 0;

      for (final x in list) {
        final s = (x["status"] ?? "pending").toString().toLowerCase();

        if (s == "accepted" || s == "approved") ap++;
        else if (s == "rejected") r++;
        else p++;
      }

      setState(() {
        applied = a;
        approved = ap;
        pending = p;
        rejected = r;
        loadingStats = false;
      });
    } catch (_) {
      setState(() => loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final bannerUrl = event["banner_url"];
    final status =
        (event["computed_status"] ?? event["status"] ?? "upcoming")
            .toString()
            .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Event Details"),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 200,
              child: bannerUrl != null && bannerUrl.toString().isNotEmpty
                  ? kIsWeb
                      ? Image.network(bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _fallbackBanner())
                      : (bannerUrl.toString().startsWith("http")
                          ? Image.network(bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fallbackBanner())
                          : Image.file(File(bannerUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fallbackBanner()))
                  : _fallbackBanner(),
            ),

            const SizedBox(height: 16),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event["title"] ?? "Untitled Event",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _statusChip(status),
                      const SizedBox(width: 10),
                      Text(
                        event["event_date"].toString().split("T")[0],
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReviewApplicationsScreen(
                                  eventId: event["id"],
                                ),
                              ),
                            );

                            if (updated == true) {
                              loadStats(); // 🔄 refresh overview
                            }
                          },
                          child: const Text("View Volunteers"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditEventScreen(event: event),
                            ),
                          );
                          if (updated == true) {
                            Navigator.pop(context, true);
                          }
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit Event"),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Event Overview",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  loadingStats
                      ? const Center(
                          child: CircularProgressIndicator())
                      : Row(
                          children: [
                            _statBox("Applied",
                                applied.toString(), Icons.person),
                            _statBox("Approved",
                                approved.toString(), Icons.check_circle),
                            _statBox("Pending",
                                pending.toString(), Icons.hourglass_bottom),
                            _statBox("Rejected",
                                rejected.toString(), Icons.cancel),
                          ],
                        ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          "Volunteers Needed: ${event["volunteers_required"] ?? 0}"),
                      Text(
                          "Slots Remaining: ${(event["volunteers_required"] ?? 0) - approved}"),
                    ],
                  )
                ],
              ),
            ),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Event Info",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _infoRow(Icons.location_on, event["location"]),
                  _infoRow(Icons.category, event["event_type"]),
                  _infoRow(Icons.calendar_today,
                      event["event_date"].toString().split("T")[0]),
                  _infoRow(Icons.timer,
                      "Application Deadline: ${event["application_deadline"]}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _fallbackBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF22C55E)]),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.white),
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  static Widget _statusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.green),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String? text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(text ?? "-")),
        ],
      ),
    );
  }
}

class _statBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _statBox(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
