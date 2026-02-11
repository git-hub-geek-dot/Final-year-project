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
  List<dynamic> _reviewsList = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchRatingSummary();
    _fetchReviews();
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

  Future<void> _fetchReviews() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingReviews = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/ratings/${widget.organiserId}"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _reviewsList = jsonDecode(response.body);
          _loadingReviews = false;
        });
      } else {
        setState(() {
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingReviews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final organiser = profile?["organiser"];
    final stats = profile?["stats"];
    
    final name = organiser?["name"] ?? "Organiser";
    final city = organiser?["city"] ?? "-";
    final email = organiser?["email"] ?? "-";
    final contact = organiser?["contact_number"] ?? "-";
    final eventsCount = stats?["events"]?.toString() ?? "0";
    final volunteersEngaged = stats?["volunteers"]?.toString() ?? "0";
    final photoUrl =
      _normalizeImageUrl(organiser?["profile_picture_url"]?.toString());

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
              _header(name, photoUrl),
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
  Widget _header(String name, String? photoUrl) {
    return _card(
      child: Column(
        children: [
          _profileAvatar(photoUrl),
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

  Widget _profileAvatar(String? imageUrl) {
    const double size = 84;

    if (imageUrl == null) {
      return const CircleAvatar(
        radius: 42,
        backgroundColor: Colors.green,
        child: Icon(Icons.eco, size: 42, color: Colors.white),
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const CircleAvatar(
            radius: 42,
            backgroundColor: Colors.green,
            child: Icon(Icons.eco, size: 42, color: Colors.white),
          );
        },
      ),
    );
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
    if (_loadingReviews) {
      return _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_reviewsList.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Volunteer Reviews",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              "No reviews yet",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show top 2 reviews
    final displayReviews = _reviewsList.take(2).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Volunteer Reviews",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...displayReviews.map((review) {
            final score = review["score"] ?? 0;
            final comment = review["comment"]?.toString() ?? "";
            final raterName = review["rater_name"]?.toString() ?? "Anonymous";
            final eventTitle = review["event_title"]?.toString() ?? "Unknown Event";
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _review(score, comment, raterName, eventTitle),
            );
          }).toList(),
          if (_reviewsList.length > 2)
            Center(
              child: TextButton(
                onPressed: _showAllReviews,
                child: Text(
                  "View All ${_reviewsList.length} Reviews",
                  style: const TextStyle(color: Color(0xFF2E6BE6)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AllReviewsModal(
        organiserId: widget.organiserId,
        reviews: _reviewsList,
      ),
    );
  }

  Widget _review(int score, String comment, String raterName, String eventTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              index < score ? Icons.star : Icons.star_border,
              size: 16,
              color: Colors.amber,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (comment.isNotEmpty) ...[
          Text(comment, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Text(
              "— $raterName",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                eventTitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E6BE6),
                ),
              ),
            ),
          ],
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

// ================= ALL REVIEWS MODAL =================
class _AllReviewsModal extends StatefulWidget {
  final int organiserId;
  final List<dynamic> reviews;

  const _AllReviewsModal({
    required this.organiserId,
    required this.reviews,
  });

  @override
  State<_AllReviewsModal> createState() => _AllReviewsModalState();
}

class _AllReviewsModalState extends State<_AllReviewsModal> {
  List<dynamic> _eventRatings = [];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    _fetchEventRatings();
  }

  Future<void> _fetchEventRatings() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        setState(() => _loadingEvents = false);
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/ratings/${widget.organiserId}/events"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _eventRatings = jsonDecode(response.body);
          _loadingEvents = false;
        });
      } else {
        setState(() => _loadingEvents = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEvents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "All Reviews",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Event Ratings Section
                if (_loadingEvents)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_eventRatings.isNotEmpty) ...[
                  const Text(
                    "Last 5 Events Overall Rating",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._eventRatings.map((event) {
                    final title = event["event_title"]?.toString() ?? "Unknown";
                    final avgRating = event["avg_rating"] ?? 0;
                    final reviewCount = event["review_count"] ?? 0;
                    final rating = double.tryParse(avgRating.toString()) ?? 0.0;
                    
                    return _eventRatingCard(title, rating, reviewCount);
                  }).toList(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                
                // Individual Reviews Section
                const Text(
                  "Individual Reviews",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...widget.reviews.map((review) {
                  final score = review["score"] ?? 0;
                  final comment = review["comment"]?.toString() ?? "";
                  final raterName = review["rater_name"]?.toString() ?? "Anonymous";
                  final eventTitle = review["event_title"]?.toString() ?? "Unknown Event";
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _reviewWidget(score, comment, raterName, eventTitle),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventRatingCard(String title, double rating, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "$count reviews",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: rating >= 4 ? Colors.green : rating >= 3 ? Colors.orange : Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewWidget(int score, String comment, String raterName, String eventTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              index < score ? Icons.star : Icons.star_border,
              size: 16,
              color: Colors.amber,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (comment.isNotEmpty) ...[
          Text(comment, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Text(
              "— $raterName",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                eventTitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E6BE6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
