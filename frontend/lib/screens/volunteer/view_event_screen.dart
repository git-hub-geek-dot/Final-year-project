import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/token_service.dart';
import '../../config/api_config.dart';


class ViewEventScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const ViewEventScreen({super.key, required this.event});

  @override
  State<ViewEventScreen> createState() => _ViewEventScreenState();
}

class _ViewEventScreenState extends State<ViewEventScreen> {
  bool isLoadingStatus = true;
  bool isApplying = false;

  bool hasApplied = false;
  String? applicationStatus; // pending | accepted | rejected

  @override
  void initState() {
    super.initState();
    _fetchApplicationStatus();
  }

  // ================= APPLICATION STATUS =================
  Future<void> _fetchApplicationStatus() async {
    try {
      final token = await TokenService.getToken();

      final response = await http.get(
       Uri.parse(
  "${ApiConfig.baseUrl}/events/${widget.event["id"]}/application-status",
),

        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          hasApplied = data["applied"] == true;
          applicationStatus = data["status"];
          isLoadingStatus = false;
        });
      } else {
        isLoadingStatus = false;
      }
    } catch (_) {
      isLoadingStatus = false;
    }
  }

  // ================= APPLY TO EVENT =================
  Future<void> _applyToEvent() async {
    setState(() => isApplying = true);

    try {
      final token = await TokenService.getToken();

      final response = await http.post(
       Uri.parse(
  "${ApiConfig.baseUrl}/events/${widget.event["id"]}/application-status",
),

        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        setState(() {
          hasApplied = true;
          applicationStatus = data["status"]; // pending
          isApplying = false;
        });
      } else if (response.statusCode == 409) {
        _snack("You have already applied");
        isApplying = false;
      } else if (response.statusCode == 400) {
        _snack("Event slots are full");
        isApplying = false;
      } else {
        _snack("Something went wrong");
        isApplying = false;
      }
    } catch (_) {
      _snack("Network error");
      setState(() => isApplying = false);
    }
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Event Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event["title"] ?? "",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.event["description"] ??
                        "No description provided by organiser.",
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _detailRow(
                    Icons.location_on,
                    widget.event["location"] ?? "Location not specified",
                  ),
                  _detailRow(
                    Icons.calendar_today,
                    widget.event["event_date"]
                            ?.toString()
                            .split("T")[0] ??
                        "",
                  ),
                  _detailRow(
                    Icons.people,
                    "${widget.event["slots_left"] ?? "N/A"} slots left",
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildApplySection(),
          ),
        ],
      ),
    );
  }

  // ================= APPLY UI =================
  Widget _buildApplySection() {
    if (isLoadingStatus) {
      return const CircularProgressIndicator();
    }

    if (!hasApplied) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isApplying ? null : () => _showTerms(context),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: EdgeInsets.zero,
          ),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            child: Center(
              child: isApplying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Apply for this Event",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    switch (applicationStatus) {
      case "pending":
        return const Text("⏳ Application Pending",
            style: TextStyle(color: Colors.orange, fontSize: 16));
      case "accepted":
        return const Text("✅ Accepted",
            style: TextStyle(color: Colors.green, fontSize: 16));
      case "rejected":
        return const Text("❌ Rejected",
            style: TextStyle(color: Colors.red, fontSize: 16));
      default:
        return const SizedBox();
    }
  }

  // ================= HELPERS =================
  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= T&C MODAL =================
  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        bool agreed = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Terms & Conditions",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _term("Profile information must be accurate."),
                  _term("Participation requires organiser approval."),
                  _term("Attendance is mandatory if accepted."),
                  _term("Misconduct may result in removal."),
                  _term(
                    "VolunteerX is only a discovery and coordination platform and does not handle, guarantee, or take responsibility for any payments, financial transactions, or agreements between volunteers and organizers.",
                  ),

                  const SizedBox(height: 8),

                  CheckboxListTile(
                    value: agreed,
                    onChanged: (v) => setState(() => agreed = v!),
                    title: const Text("I agree to the Terms & Conditions"),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: agreed
                          ? () {
                              Navigator.pop(context);
                              _applyToEvent();
                            }
                          : null,
                      child: const Text("Confirm & Apply"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _term(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text("• $text"),
    );
  }
}
