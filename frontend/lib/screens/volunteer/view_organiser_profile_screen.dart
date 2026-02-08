import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/rating_service.dart';
import '../../services/token_service.dart';

class ViewOrganiserProfileScreen extends StatefulWidget {
  final int organiserId;

  const ViewOrganiserProfileScreen({
    super.key,
    required this.organiserId,
  });

  @override
  State<ViewOrganiserProfileScreen> createState() =>
      _ViewOrganiserProfileScreenState();
}

class _ViewOrganiserProfileScreenState extends State<ViewOrganiserProfileScreen> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? profile;
  String _ratingValue = "0.0";
  String _ratingCount = "0";

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchRatingSummary();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/organisers/${widget.organiserId}"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          profile = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to load organiser profile";
          isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Network error";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchRatingSummary() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final data = await RatingService.fetchSummary(widget.organiserId);
      if (!mounted) return;

      setState(() {
        _ratingValue = data["rating"]?.toString() ?? _ratingValue;
        _ratingCount = data["review_count"]?.toString() ?? _ratingCount;
      });
    } catch (_) {
      // Keep defaults
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?["name"] ?? "Organiser";
    final city = profile?["city"] ?? "-";
    final email = profile?["email"] ?? "-";
    final contact = profile?["contact_number"] ?? "-";
    final eventsCount = profile?["events_count"]?.toString() ?? "0";
    final volunteersEngaged =
        profile?["volunteers_engaged"]?.toString() ?? "0";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Organiser Profile"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!isLoading && errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(errorMessage!),
              ),
            if (!isLoading && errorMessage == null) ...[
              _header(name),
            const SizedBox(height: 16),
            _about(city),
            const SizedBox(height: 16),
            _stats(volunteersEngaged, eventsCount),
            const SizedBox(height: 16),
            _reviews(),
            const SizedBox(height: 16),
            _connectCard(email, contact),
            ],
            
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _header(String name) {
    return _card(
      child: Column(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Colors.green,
            child: Icon(Icons.eco, size: 42, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "⭐ $_ratingValue ($_ratingCount)",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ================= ABOUT =================
  Widget _about(String city) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About Organisation",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            city == "-"
                ? "No description provided by organiser."
                : "Based in $city.",
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ================= STATS =================
  Widget _stats(String volunteersEngaged, String eventsCount) {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(volunteersEngaged, "Volunteers"),
          _Stat(eventsCount, "Events"),
          _Stat(_ratingValue, "Rating"),
        ],
      ),
    );
  }

  Widget _connectCard(String email, String contact) {
  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Connect with Us",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 4),

        const Text(
          "Follow or visit to learn more about their work",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _socialIcon(Icons.language, "Website"),
            _socialIcon(Icons.camera_alt, "Instagram"),
            _socialIcon(Icons.facebook, "Facebook"),
            _socialIcon(Icons.link, "LinkedIn"),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(height: 1),

        const SizedBox(height: 12),

        Row(
          children: [
            const Icon(Icons.email, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.phone, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              contact,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    ),
  );
}



Widget _socialIcon(IconData icon, String label) {
  return Column(
    children: [
      InkWell(
        onTap: () {
          debugPrint("$label clicked");
        },
        borderRadius: BorderRadius.circular(50),
        child: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.green.withOpacity(0.15),
          child: Icon(icon, color: Colors.green),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}



  // ================= REVIEWS =================
  Widget _reviews() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Volunteer Reviews",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _review(
            "Very well organised and safe volunteering experience.",
            "Aditi",
          ),
          const SizedBox(height: 12),
          _review(
            "Clear instructions and friendly coordinators.",
            "Rahul",
          ),
        ],
      ),
    );
  }

  Widget _review(String text, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
            Icon(Icons.star, size: 16, color: Colors.amber),
          ],
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          "— $name",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ================= CARD =================
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ================= STAT =================
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
