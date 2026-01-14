import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/token_service.dart';
import 'view_organiser_profile_screen.dart';

class ViewEventScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const ViewEventScreen({super.key, required this.event});

  @override
  State<ViewEventScreen> createState() => _ViewEventScreenState();
}

class _ViewEventScreenState extends State<ViewEventScreen> {
  bool isLoadingStatus = true;
  bool isApplying = false;

  /// null | pending | accepted | rejected
  String? applicationStatus;

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
          "http://10.0.2.2:4000/api/events/${widget.event["id"]}/application-status",
        ),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          applicationStatus =
              data["applied"] == true ? data["status"] : null;
          isLoadingStatus = false;
        });
      } else {
        isLoadingStatus = false;
      }
    } catch (_) {
      isLoadingStatus = false;
    }
  }

  // ================= APPLY =================
  Future<void> _applyToEvent() async {
    setState(() => isApplying = true);

    try {
      final token = await TokenService.getToken();

      final response = await http.post(
        Uri.parse(
          "http://10.0.2.2:4000/api/events/${widget.event["id"]}/apply",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          applicationStatus = data["status"];
          isApplying = false;
        });
      } else {
        _snack("Unable to apply");
        isApplying = false;
      }
    } catch (_) {
      _snack("Network error");
      setState(() => isApplying = false);
    }
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Event Details"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                _eventHeaderCard(),
                const SizedBox(height: 16),
                _aboutCard(),
                const SizedBox(height: 16),
                _responsibilitiesCard(),
                const SizedBox(height: 16),
                _organiserCard(),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildApplySection(),
          ),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _eventHeaderCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event["title"] ?? "",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            widget.event["description"] ?? "",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _iconRow(Icons.location_on, widget.event["location"] ?? "N/A"),
          _iconRow(
            Icons.calendar_today,
            widget.event["event_date"]?.toString().split("T")[0] ?? "",
          ),
          _iconRow(
            Icons.people,
            "Volunteers Needed: ${widget.event["volunteers_required"] ?? "N/A"}",
          ),
          if (applicationStatus != null) ...[
            const SizedBox(height: 16),
            _statusPill(
              _statusText(applicationStatus!),
              _statusColor(applicationStatus!),
            ),
          ],
        ],
      ),
    );
  }

  // ================= ABOUT =================
  Widget _aboutCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About this Event",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.event["description"] ??
                "No description provided by organiser.",
          ),
        ],
      ),
    );
  }

  // ================= RESPONSIBILITIES =================
  Widget _responsibilitiesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Responsibilities",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _checkItem("Assist in cleanup activities"),
          _checkItem("Segregate recyclable and non-recyclable waste"),
          _checkItem("Follow safety and cleanliness guidelines"),
        ],
      ),
    );
  }

  // ================= ORGANISER =================
  Widget _organiserCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ViewOrganiserProfileScreen(
              organiserId: 1, // TODO: dynamic later
            ),
          ),
        );
      },
      child: _card(
        child: Row(
          children: const [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.green,
              child: Icon(Icons.eco, color: Colors.white),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Green Earth Foundation",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  "⭐ 4.6 rating | 120+ volunteers engaged",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= APPLY =================
  Widget _buildApplySection() {
    if (isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    if (applicationStatus == null) {
      return SizedBox(
        height: 54,
        width: double.infinity,
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
                          color: Colors.white),
                    ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ================= HELPERS =================
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Widget _iconRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      height: 54,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "pending":
        return "⏳ Application Pending";
      case "accepted":
        return "✅ Application Approved";
      case "rejected":
        return "❌ Application Rejected";
      default:
        return "";
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= TERMS =================
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
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Terms & Conditions",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: agreed,
                    onChanged: (v) => setState(() => agreed = v!),
                    title: const Text("I agree to the Terms & Conditions"),
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
}
