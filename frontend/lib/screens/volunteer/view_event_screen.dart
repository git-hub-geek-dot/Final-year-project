import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/saved_events_service.dart';
import 'view_organiser_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../rating/rating_screen.dart';
import '../../widgets/robust_image.dart';

class ViewEventScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const ViewEventScreen({super.key, required this.event});

  @override
  State<ViewEventScreen> createState() => _ViewEventScreenState();
}

class _ViewEventScreenState extends State<ViewEventScreen> {
  bool isLoadingStatus = true;
  bool isApplying = false;
  bool isSaved = false;
  String? organiserPhotoUrl;

  /// null | pending | accepted | rejected
  String? applicationStatus;

  @override
  void initState() {
    super.initState();
    _fetchApplicationStatus();
    _loadSavedState();
    _loadOrganiserPhoto();
  }

  Future<void> _loadOrganiserPhoto() async {
    final eventPhoto =
        widget.event["organiser_profile_picture_url"]?.toString();
    final normalisedEventPhoto = _normalizeImageUrl(eventPhoto);
    if (normalisedEventPhoto != null) {
      setState(() {
        organiserPhotoUrl = normalisedEventPhoto;
      });
      return;
    }

    final organiserId = widget.event["organiser_id"];
    if (organiserId == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/organisers/$organiserId"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final photo = _normalizeImageUrl(
          data["profile_picture_url"]?.toString(),
        );

        if (photo != null) {
          setState(() {
            organiserPhotoUrl = photo;
          });
        }
      }
    } catch (_) {
      // Keep fallback avatar on error.
    }
  }

  Future<void> _loadSavedState() async {
    final id = widget.event["id"]?.toString();
    if (id == null) return;

    final saved = await SavedEventsService.isSaved(id);
    if (!mounted) return;

    setState(() {
      isSaved = saved;
    });
  }

  Future<void> _toggleSaved() async {
    final updated = await SavedEventsService.toggleSaved(widget.event);
    if (!mounted) return;

    setState(() {
      isSaved = updated;
    });

    _snack(updated ? "Saved event" : "Removed from saved");
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
          applicationStatus = data["applied"] == true ? data["status"] : null;
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
        final nextStatus =
            (data["status"]?.toString().toLowerCase() ?? "pending");
        setState(() {
          applicationStatus = nextStatus;
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
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSaved,
            tooltip: isSaved ? "Remove from saved" : "Save event",
          ),
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
    final imageUrl = _normalizeImageUrl(widget.event["banner_url"]?.toString());

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: const Center(
          child: Icon(Icons.image, size: 48, color: Color(0xFF2E6BE6)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: RobustImage(
        url: imageUrl,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
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
            "${_formatTime(widget.event["start_time"])} - ${_formatTime(widget.event["end_time"])}",
          ),
          _iconRow(
            Icons.people,
            "Volunteers Needed: ${widget.event["volunteers_required"] ?? "N/A"}",
          ),
          _iconRow(
            Icons.payments,
            _paymentText(
              widget.event["event_type"],
              widget.event["payment_per_day"],
            ),
          ),
          if ((widget.event["computed_status"] == "completed") &&
              (applicationStatus == "accepted" ||
                  applicationStatus == "completed")) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final organiserId = widget.event["organiser_id"];
                  if (organiserId == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RatingScreen(
                        eventId: widget.event["id"],
                        rateeId: organiserId,
                        title: "Rate Organiser",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.star_border),
                label: const Text("Rate organiser"),
              ),
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
          if (items.isNotEmpty) ...items.map(_checkItem),
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
            _organiserAvatar(organiserPhotoUrl),
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

  Widget _organiserAvatar(String? imageUrl) {
    const double size = 44;

    if (imageUrl == null) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.green,
        child: Icon(Icons.eco, color: Colors.white),
      );
    }

    return ClipOval(
      child: RobustImage(
        url: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: const CircleAvatar(
          radius: 22,
          backgroundColor: Colors.green,
          child: Icon(Icons.eco, color: Colors.white),
        ),
      ),
    );
  }

  // ================= APPLY =================
  Widget _buildApplySection() {
    if (isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    final computedStatus = widget.event["computed_status"]?.toString();
    final status = widget.event["status"]?.toString();
    final isCompleted = computedStatus == "completed" || _isPastEvent();
    final isClosed = status != null && status != "open";

    if (isCompleted || isClosed) {
      return SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: EdgeInsets.zero,
          ),
          child: const Text(
            "Applications closed",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
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

    return _statusPill(
      _statusText(applicationStatus!),
      _statusColor(applicationStatus!),
    );
  }

  // ================= HELPERS =================
  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return "N/A";
    try {
      final time = timeValue.toString();
      return time.length >= 5 ? time.substring(0, 5) : time;
    } catch (_) {
      return "N/A";
    }
  }

  bool _isPastEvent() {
    final eventDateRaw = widget.event["event_date"]?.toString();
    if (eventDateRaw == null || eventDateRaw.isEmpty) return false;

    final parsed = DateTime.tryParse(eventDateRaw);
    if (parsed == null) return false;

    final now = DateTime.now();
    final eventDateOnly = DateTime(parsed.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);

    return eventDateOnly.isBefore(today);
  }

  String? _normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    String trimmed = url.trim();
    
    // Replace localhost with 10.0.2.2 for Android emulator
    if (trimmed.contains("localhost")) {
      trimmed = trimmed.replaceAll("localhost", "10.0.2.2");
    }
    
    if (trimmed.startsWith("http")) return trimmed;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    return trimmed.startsWith("/") ? "$origin$trimmed" : "$origin/$trimmed";
  }

  String _paymentText(dynamic eventType, dynamic paymentPerDay) {
    final type = eventType?.toString().toLowerCase();
    if (type == "paid") {
      final amount = paymentPerDay?.toString();
      if (amount != null && amount.isNotEmpty) {
        return "Paid: ₹$amount/day";
      }
      return "Paid";
    }
    return "Unpaid";
  }

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                      "• Participation is voluntary and does not constitute employment."),
                  const SizedBox(height: 8),
                  const Text(
                      "• Volunteers must follow organiser instructions and maintain respectful conduct."),
                  const SizedBox(height: 8),
                  const Text(
                      "• Volunteers are responsible for their own safety during the event."),
                  const SizedBox(height: 8),
                  const Text(
                      "• Accurate profile and contact information must be maintained at all times."),
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
