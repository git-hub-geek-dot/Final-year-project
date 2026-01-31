import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/token_service.dart';
import 'view_organiser_profile_screen.dart';
import 'package:share_plus/share_plus.dart';

String formatTime(String? time) {
  if (time == null) return "";
  final parts = time.split(":");
  int hour = int.parse(parts[0]);
  final minute = parts[1];
  final suffix = hour >= 12 ? "PM" : "AM";
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return "$hour:$minute $suffix";
}



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
          "${ApiConfig.baseUrl}/events/${widget.event["id"]}/application-status",
        ),
        headers: {"Authorization": "Bearer $token"},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          applicationStatus =
              data["applied"] == true ? data["status"] : null;
          isLoadingStatus = false;
        });
      } else {
        setState(() {
          isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingStatus = false;
      });
    }
  }

  // ================= APPLY =================
  Future<void> _applyToEvent() async {
    setState(() => isApplying = true);

    try {
      final token = await TokenService.getToken();

      final response = await http.post(
        Uri.parse(
          "${ApiConfig.baseUrl}/events/${widget.event["id"]}/apply",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          applicationStatus = data["status"];
          isApplying = false;
        });
      } else {
        _snack("Unable to apply");
        setState(() {
          isApplying = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
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
  actions: [
    IconButton(
      icon: const Icon(Icons.share),
      onPressed: () {
        final text = """
${widget.event["title"]}
Location: ${widget.event["location"]}
Date: ${widget.event["event_date"].toString().split("T")[0]}


Join on VolunteerX
""";

        Share.share(text);
      },
    ),
  ],
),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
  children: [
    _eventBanner(),
    const SizedBox(height: 16),
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
Widget _eventBanner() {
  final imageUrl = widget.event["banner_url"];

  if (imageUrl == null || imageUrl.isEmpty) {
    return const SizedBox.shrink();
  }

  return ClipRRect(
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(24),
    ),
    child: Image.network(
      imageUrl,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 220,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          height: 220,
          color: Colors.grey.shade300,
          child: const Icon(Icons.image, size: 48),
        );
      },
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
  style: const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  ),
),
const SizedBox(height: 6),
Text(
  widget.event["description"] ?? "",
  style: TextStyle(
    color: Colors.grey.shade600,
    height: 1.4,
  ),
),

          const SizedBox(height: 16),
         _iconRow(Icons.location_on, widget.event["location"] ?? "N/A"),
_iconRow(
  Icons.calendar_today,
  widget.event["event_date"]?.toString().split("T")[0] ?? "",
),
_iconRow(
  Icons.access_time,
  "${formatTime(widget.event['start_time'])} - ${formatTime(widget.event['end_time'])}",
),
_iconRow(
  Icons.people,
  "Volunteers Needed: ${widget.event["volunteers_required"]}",
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
    final items = (widget.event["responsibilities"] as List?)
            ?.whereType<String>()
            .toList() ??
        [];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Responsibilities",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text("No responsibilities provided by organiser."),
          if (items.isNotEmpty)
            ...items.map(_checkItem),
        ],
      ),
    );
  }

  // ================= ORGANISER =================
  Widget _organiserCard() {
    final organiserId = widget.event["organiser_id"];
    final organiserName = widget.event["organiser_name"] ?? "Organiser";

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (organiserId == null) {
          _snack("Organiser profile not available");
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewOrganiserProfileScreen(
              organiserId: organiserId,
            ),
          ),
        );
      },
      child: _card(
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.green,
              child: Icon(Icons.eco, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organiserName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "View organiser profile",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
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
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        colors: [
          Colors.white,
          const Color(0xFFF7FAFF),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}


  Widget _iconRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.green),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
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
    height: 52,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withOpacity(0.15),
          color.withOpacity(0.25),
        ],
      ),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Center(
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    "Volunteer Terms & Conditions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                const Text("• Participation is voluntary and does not constitute employment."),
                const SizedBox(height: 8),
                const Text("• Volunteers must follow organiser instructions and maintain respectful conduct."),
                const SizedBox(height: 8),
                const Text("• Volunteers are responsible for their own safety during the event."),
                const SizedBox(height: 8),
                const Text("• Accurate profile and contact information must be maintained at all times."),
                const SizedBox(height: 8),
                const Text(
                  "• VolunteerX is not responsible for any payments, donations, reimbursements, or financial matters related to events; all such transactions are solely between the volunteer and the organiser.",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 16),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
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