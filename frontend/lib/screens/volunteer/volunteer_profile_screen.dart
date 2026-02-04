import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';
import '../auth/login_screen.dart';

import 'edit_profile_screen.dart';
import 'my_applications_screen.dart';
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

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  bool loading = true;
  String? errorMessage;

  int? _imageCacheBuster;

  String? name;
  String? email;
  String? city;
  String? role;
  String? verificationStatus;
  String? profilePictureUrl;

  List<String> _skills = [];
  List<String> _interests = [];
  String _impactEvents = '0';
  String _impactRating = '0';
  Map<String, dynamic>? _upcomingEvent;
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    fetchProfile();
    loadVerificationStatus();
    fetchDashboard();
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          role = data["role"];
          profilePictureUrl = _normalizeProfileImageUrl(
            data["profile_picture_url"],
          );
          _imageCacheBuster = DateTime.now().millisecondsSinceEpoch;
          loading = false;
        });
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

    if (url.contains("localhost") || url.contains("127.0.0.1")) {
      final parsed = Uri.tryParse(url);
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
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return const CircleAvatar(
        radius: 42,
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: 42),
      );
    }

    final imageUrl = "${normalizedUrl}?v=${_imageCacheBuster ?? 0}";

    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 42),
        ),
      ),
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

  Future<void> _savePreferences({
    required List<String> skills,
    required List<String> interests,
  }) async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final url = Uri.parse("${ApiConfig.baseUrl}/volunteer/preferences");
      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "skills": skills,
          "interests": interests,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _skills = skills;
          _interests = interests;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preferences saved ✅")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _showEditSkillsInterestsSheet() async {
    final skillsController = TextEditingController(text: _skills.join(", "));
    final interestsController =
        TextEditingController(text: _interests.join(", "));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Edit Skills & Interests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: skillsController,
                  decoration: const InputDecoration(
                    labelText: "Skills (comma separated)",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interestsController,
                  decoration: const InputDecoration(
                    labelText: "Interests (comma separated)",
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final skills = skillsController.text
                              .split(",")
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          final interests = interestsController.text
                              .split(",")
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                          Navigator.pop(context);
                          _savePreferences(
                            skills: skills,
                            interests: interests,
                          );
                        },
                        child: const Text("Save"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                );
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
                            _statCard("Rating", _impactRating, Icons.star),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ================= UPCOMING COMMITMENT =================
                      _sectionHeader("Upcoming Commitment"),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.calendar_month),
                            title: Text(
                              _upcomingEvent == null
                                  ? "No upcoming events"
                                  : (_upcomingEvent!["title"] ?? "Upcoming Event"),
                            ),
                            subtitle: Text(
                              _upcomingEvent == null
                                  ? ""
                                  : "${_upcomingEvent!["event_date"] ?? ""} • ${_upcomingEvent!["start_time"] ?? ""} • ${_upcomingEvent!["location"] ?? ""}",
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ================= SKILLS & INTERESTS =================
                      _sectionHeader(
                        "Skills & Interests",
                        onEdit: _showEditSkillsInterestsSheet,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._skills.map(
                              (s) => Chip(
                                label: Text(s),
                                backgroundColor: const Color(0xFFEFF6FF),
                              ),
                            ),
                            ..._interests.map(
                              (s) => Chip(
                                label: Text(s),
                                backgroundColor: const Color(0xFFECFDF3),
                              ),
                            ),
                            if (_skills.isEmpty && _interests.isEmpty)
                              const Text("No skills/interests set"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ================= ACTIVITY TIMELINE =================
                      _sectionHeader("Recent Activity"),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            if (_activity.isEmpty)
                              const Text("No recent activity"),
                            ..._activity.map(
                              (a) => _timelineItem(
                                a["title"]?.toString() ?? "Event",
                                a["status"]?.toString() ?? "pending",
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

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
                              "Payment History",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PaymentHistoryScreen(),
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
