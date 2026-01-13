import 'package:flutter/material.dart';

class EventDetailsScreen extends StatelessWidget {
  final Map event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final bannerUrl = event["banner_url"];

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
            // 🔝 Banner
            SizedBox(
              width: double.infinity,
              height: 200,
              child: bannerUrl != null && bannerUrl.toString().isNotEmpty
                  ? Image.network(bannerUrl, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // 📦 Main Card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event["title"] ?? "Untitled Event",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      _statusChip(event["status"] ?? "Open"),
                      const SizedBox(width: 10),
                      Text(
                        event["event_date"]
                            .toString()
                            .split("T")[0],
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text("View Volunteers"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit Event"),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 📊 Overview Stats
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Event Overview",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _statBox("Applied", "32", Icons.person),
                      _statBox("Approved", "18", Icons.check_circle),
                      _statBox("Pending", "10", Icons.hourglass_bottom),
                      _statBox("Rejected", "4", Icons.cancel),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Volunteers Needed: 20"),
                      Text("Slots Remaining: 12"),
                    ],
                  )
                ],
              ),
            ),

            // 📍 Event Info
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Event Overview",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.location_on, event["location"]),
                  _infoRow(Icons.category, event["category"]),
                  _infoRow(
                    Icons.calendar_today,
                    event["event_date"].toString().split("T")[0],
                  ),
                  _infoRow(Icons.timer, "Application Deadline: 15 Jan 2025"),
                ],
              ),
            ),

            // ⚠ Alerts
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Event Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _warning("2 approved volunteers have not confirmed attendance"),
                  _warning("Less than 24 hours left — 10 approvals pending"),
                ],
              ),
            ),
          ],
        ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _warning extends StatelessWidget {
  final String text;
  const _warning(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.warning, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
