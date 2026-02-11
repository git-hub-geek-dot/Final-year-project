import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';
import '../../services/rating_service.dart';
import '../auth/login_screen.dart';

import 'edit_profile_screen.dart';
import 'my_applications_screen.dart';
import 'saved_events_screen.dart';
import 'payment_history_screen.dart';
import 'invite_friends_screen.dart';
import 'help_support_screen.dart';
import 'get_verified_screen.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen>
  with SingleTickerProviderStateMixin {
  bool loading = true;
  String? errorMessage;
  bool _handlingUnauthorized = false;

  int? _imageCacheBuster;

  String? name;
  String? email;
  String? city;
  String? role;
  String? verificationStatus;
  String? profilePictureUrl;
  String? _lastProfilePictureUrl;
  bool _pendingAvatarSuccess = false;

  late final AnimationController _avatarSuccessController;
  late final Animation<double> _avatarGlow;

  List<String> _skills = [];
  List<String> _interests = [];
  String _impactEvents = '0';
  String _impactRating = '0';
  String _ratingCount = '0';
  Map<String, dynamic>? _upcomingEvent;
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    _avatarSuccessController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _avatarGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _avatarSuccessController,
        curve: Curves.easeOutCubic,
      ),
    );
    fetchProfile();
    loadVerificationStatus();
    fetchDashboard();
    loadRatingSummary();
  }

  @override
  void dispose() {
    _avatarSuccessController.dispose();
    super.dispose();
  }

  Future<void> loadVerificationStatus() async {
    final status = await VerificationService.getStatus();
    setState(() {
      verificationStatus = status;
    });
  }

  Future<void> fetchDashboard() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/volunteer/dashboard");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final impact = data["impact"] ?? {};
        setState(() {
          _impactEvents = (impact["events"] ?? 0).toString();
          _impactRating = (impact["rating"] ?? "0").toString();
          _upcomingEvent = data["upcomingEvent"];
          _skills = List<String>.from(data["skills"] ?? []);
          _interests = List<String>.from(data["interests"] ?? []);
          _activity = List<Map<String, dynamic>>.from(
            data["activity"] ?? [],
          );
        });
      }
    } catch (_) {
      // Keep existing state on error
    }
  }

  Future<void> loadRatingSummary() async {
    try {
      final userId = await TokenService.getUserId();
      if (userId == null) return;

      final data = await RatingService.fetchSummary(userId);
      setState(() {
        _impactRating = data["rating"]?.toString() ?? _impactRating;
        _ratingCount = data["review_count"]?.toString() ?? _ratingCount;
      });
    } catch (_) {
      // Keep existing values
    }
  }

  /// ================= FETCH PROFILE FROM API =================
  Future<void> fetchProfile() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final token = await TokenService.getToken();

      if (token == null || token.isEmpty) {
        setState(() {
          loading = false;
          errorMessage = "Token not found. Please login again.";
        });
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/profile");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final normalizedUrl = _normalizeProfileImageUrl(
          data["profile_picture_url"],
        );
        final previousUrl = _lastProfilePictureUrl;

        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          role = data["role"];
          profilePictureUrl = normalizedUrl;
          _imageCacheBuster = DateTime.now().millisecondsSinceEpoch;
          loading = false;
        });


        _lastProfilePictureUrl = normalizedUrl;
        if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
          if (_pendingAvatarSuccess || normalizedUrl != previousUrl) {
            _triggerAvatarSuccess(delay: true);
          }
        }
        _pendingAvatarSuccess = false;
      } else {
        setState(() {
          loading = false;
          errorMessage = "Error ${response.statusCode}: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = "Error: $e";
      });
    }
  }


  void _triggerAvatarSuccess({bool delay = false}) {
    if (_avatarSuccessController.isAnimating) return;
    if (delay) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _avatarSuccessController.forward(from: 0);
        }
      });
      return;
    }
    _avatarSuccessController.forward(from: 0);
  }

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    await TokenService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// ================= LOGOUT =================
  Future<void> logout() async {
    await TokenService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  double _profileCompletionPercent() {
    final total = 5;
    var completed = 0;

    if ((name ?? '').trim().isNotEmpty) completed++;
    if ((email ?? '').trim().isNotEmpty) completed++;
    if ((city ?? '').trim().isNotEmpty) completed++;
    if ((profilePictureUrl ?? '').trim().isNotEmpty) completed++;
    if ((verificationStatus ?? '').trim().isNotEmpty) completed++;

    return completed / total;
  }

  List<String> _missingProfileItems() {
    final missing = <String>[];
    if ((name ?? '').trim().isEmpty) missing.add("Name");
    if ((email ?? '').trim().isEmpty) missing.add("Email");
    if ((city ?? '').trim().isEmpty) missing.add("City");
    if ((profilePictureUrl ?? '').trim().isEmpty) {
      missing.add("Profile photo");
    }
    if ((verificationStatus ?? '').trim().isEmpty) {
      missing.add("Verification status");
    }
    return missing;
  }

  String? _normalizeProfileImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    if (url.startsWith("/uploads/")) {
      return "$origin$url";
    }

    if (url.startsWith("uploads/")) {
      return "$origin/$url";
    }

    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.hasScheme) {
      if (ApiConfig.useCloud) {
        return url;
      }

      final host = parsed.host;
      final isLocalLike = host == "localhost" ||
          host == "127.0.0.1" ||
          host.startsWith("10.") ||
          host.startsWith("192.168.") ||
          host.startsWith("172.");

      if (isLocalLike && host != baseUri.host) {
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    if (url.contains("localhost") || url.contains("127.0.0.1")) {
      if (parsed != null) {
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    return url;
  }

  Widget _buildProfileAvatar() {
    final normalizedUrl = _normalizeProfileImageUrl(profilePictureUrl);
    final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;
    final imageUrl = hasImage
        ? "${normalizedUrl}?v=${_imageCacheBuster ?? 0}"
        : null;

    return AnimatedBuilder(
      animation: _avatarSuccessController,
      builder: (context, _) {
        final glow = _avatarGlow.value;
        final glowOpacity = (1 - glow) * 0.85;
        final glowSize = 96 + (glow * 26);
        return Stack(
          alignment: Alignment.center,
          children: [
            if (hasImage)
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(glowOpacity * 0.6),
                  border: Border.all(
                    color: Colors.green.withOpacity(glowOpacity),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(glowOpacity),
                      blurRadius: 32 * (1 - glow),
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              child: hasImage
                  ? ClipOval(
                      child: Image.network(
                        imageUrl!,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person, size: 42),
                      ),
                    )
                  : const Icon(Icons.person, size: 42),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logout();
    }
  }

  Future<void> _deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Token not found. Please login again.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action is irreversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/account/deactivate"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        await prefs.clear();
        await TokenService.clearToken();

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deleted successfully ✅")),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        String msg = "Delete failed";
        try {
          final data = jsonDecode(response.body);
          msg = data["message"] ?? data["error"] ?? msg;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server error: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      /// ================= HEADER =================
                      Container(
                        padding: const EdgeInsets.only(top: 60, bottom: 30),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2E6BE6),
                              Color(0xFF2ECC71)
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildProfileAvatar(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name ?? "",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (verificationStatus == "approved") ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              city == null || city!.isEmpty
                                  ? "City not set"
                                  : "$city, India",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),

                            /// EDIT PROFILE
                            GestureDetector(
                              onTap: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                );
                                if (updated == true) {
                                  _pendingAvatarSuccess = true;
                                }
                                fetchProfile();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  "Edit Profile",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// ================= PROFILE COMPLETENESS =================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Profile Completeness",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: _profileCompletionPercent(),
                                    minHeight: 10,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF22C55E),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${(_profileCompletionPercent() * 100).round()}% complete",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_missingProfileItems().isNotEmpty)
                                  Text(
                                    "Missing: ${_missingProfileItems().join(', ')}",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// ================= IMPACT SUMMARY =================
                      _sectionHeader("Impact Summary"),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _statCard("Events", _impactEvents, Icons.event),
                            const SizedBox(width: 10),
                            _statCard(
                              "Rating",
                              "$_impactRating ($_ratingCount)",
                              Icons.star,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ================= ACTIVITIES =================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _tile(
                              Icons.assignment,
                              "My Applications",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyApplicationsScreen(),
                                  ),
                                );
                              },
                            ),

                            _tile(
                              Icons.bookmark,
                              "Saved Events",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SavedEventsScreen(),
                                  ),
                                );
                              },
                            ),

                            /// ✅ GET VERIFIED (SAFE LOGIC)
                            _tile(
                              Icons.verified,
                              verificationStatus == "pending"
                                  ? "Verification Under Review"
                                  : verificationStatus == "approved"
                                      ? "Verified"
                                      : "Get Verified",
                              verificationStatus == "pending" ||
                                      verificationStatus == "approved"
                                  ? () {}
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const VolunteerGetVerifiedScreen(),
                                        ),
                                      );
                                    },
                            ),

                            _tile(
                              Icons.payments,
                              "Payment Status",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CompensationStatusScreen(),
                                  ),
                                );
                              },
                            ),
                            _tile(
                              Icons.group,
                              "Invite Friends",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const InviteFriendsScreen(),
                                  ),
                                );
                              },
                            ),
                            _tile(
                              Icons.help_outline,
                              "Help & Support",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HelpSupportScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _tile(
                              Icons.logout,
                              "Logout",
                              _confirmLogout,
                              color: Colors.red,
                            ),
                            _tile(
                              Icons.delete_forever,
                              "Delete Account",
                              _deleteAccount,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              child: const Text("Edit"),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2E6BE6)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineItem(String title, String subtitle) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.circle, size: 10, color: Color(0xFF2ECC71)),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
