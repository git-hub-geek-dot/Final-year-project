import 'package:flutter/material.dart';

class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final applications = [
      {
        "title": "Beach Cleanup Drive",
        "location": "Goa",
        "status": "Pending",
      },
      {
        "title": "Community Food Drive",
        "location": "Bengaluru",
        "status": "Accepted",
      },
      {
        "title": "Tree Plantation",
        "location": "Mysuru",
        "status": "Rejected",
      },
    ];

    Color statusColor(String status) {
      switch (status) {
        case "Accepted":
          return Colors.green;
        case "Rejected":
          return Colors.red;
        default:
          return Colors.orange;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Applications")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final app = applications[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(app["title"]!),
              subtitle: Text(app["location"]!),
              trailing: Chip(
                label: Text(app["status"]!),
                backgroundColor: statusColor(app["status"]!).withOpacity(0.15),
                labelStyle: TextStyle(color: statusColor(app["status"]!)),
              ),
            ),
          );
        },
      ),
    );
  }
}
