import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/token_service.dart';

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  bool loading = true;
  List applications = [];

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse("http://10.0.2.2:4000/api/applications/my"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        applications = jsonDecode(response.body);
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Applications")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : applications.isEmpty
              ? const Center(child: Text("No applications yet"))
              : ListView.builder(
                  itemCount: applications.length,
                  itemBuilder: (context, index) {
                    final app = applications[index];

                    return ListTile(
                      title: Text(app["title"]),
                      subtitle: Text(
                        "${app["location"]} • ${app["event_date"].toString().split("T")[0]}",
                      ),
                      trailing: _statusChip(app["status"]),
                    );
                  },
                ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case "accepted":
        color = Colors.green;
        break;
      case "rejected":
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
    );
  }
}
  