import 'package:flutter/material.dart';

class EventDetailsScreen extends StatelessWidget {
  final Map event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _title(event["title"]),
            const SizedBox(height: 10),

            _infoRow(Icons.location_on, event["location"]),
            _infoRow(Icons.calendar_today,
                event["event_date"].toString().split("T")[0]),

            if (event["start_time"] != null && event["end_time"] != null)
              _infoRow(
                Icons.access_time,
                "${event["start_time"]} - ${event["end_time"]}",
              ),

            _infoRow(Icons.people,
                "Volunteers Required: ${event["volunteers_required"]}"),

            _infoRow(
              Icons.info,
              "Status: ${(event["computed_status"] ?? event["status"]).toString().toUpperCase()}",
            ),

            const Divider(height: 30),

            const Text(
              "Description",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              event["description"] ?? "No description provided",
              style: const TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 20),

            if (event["event_type"] == "paid")
              _infoRow(
                Icons.currency_rupee,
                "Payment per day: ₹${event["payment_per_day"]}",
              ),
          ],
        ),
      ),
    );
  }

  Widget _title(String? text) {
    return Text(
      text ?? "Untitled Event",
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoRow(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value ?? "-",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
