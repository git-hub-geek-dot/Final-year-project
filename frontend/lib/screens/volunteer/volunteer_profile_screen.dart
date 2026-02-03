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
import 'my_badges_screen.dart';
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

@override
void initState() {
  super.initState();
  fetchProfile();
  loadVerificationStatus();
}




Future<void> loadVerificationStatus() async {
  final status = await VerificationService.getStatus();
  setState(() {
    verificationStatus = status;
  });
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

        print("Profile data fetched: $data");
        print("Profile picture URL from API: ${data["profile_picture_url"]}");

        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          role = data["role"];
          profilePictureUrl = _normalizeProfileImageUrl(
            data["profile_picture_url"],
          );
          print("Normalized URL: $profilePictureUrl");
          _imageCacheBuster = DateTime.now().millisecondsSinceEpoch;
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage =
              "Error ${response.statusCode}: ${response.body}";
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
    if (url == null || url.trim().isEmpty) {
      print("URL is null or empty: '$url'");
      return null;
    }

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    print("Normalizing URL: '$url' with origin: '$origin'");

    if (url.startsWith("/uploads/")) {
      final normalized = "$origin$url";
      print("Normalized /uploads/ path to: $normalized");
      return normalized;
    }

    if (url.startsWith("uploads/")) {
      final normalized = "$origin/$url";
      print("Normalized uploads/ path to: $normalized");
      return normalized;
    }

    if (url.contains("localhost") || url.contains("127.0.0.1")) {
      final parsed = Uri.tryParse(url);
      if (parsed != null) {
        final pathWithQuery = parsed.hasQuery
            ? "${parsed.path}?${parsed.query}"
            : parsed.path;
        final normalized = "$origin$pathWithQuery";
        print("Normalized localhost URL to: $normalized");
        return normalized;
      }
    }

    print("Returning URL as-is: $url");
    return url;
  }

  Widget _buildProfileAvatar() {
    final normalizedUrl = _normalizeProfileImageUrl(profilePictureUrl);
    print("Building avatar with URL: $normalizedUrl");
    
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return const CircleAvatar(
        radius: 42,
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: 42),
      );
    }

    final imageUrl = "${normalizedUrl}?v=${_imageCacheBuster ?? 0}";
    print("Final image URL: $imageUrl");

    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("Image load error: $error");
            print("Stack trace: $stackTrace");
            return const Icon(Icons.person, size: 42);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
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
                        padding:
                            const EdgeInsets.only(top: 60, bottom: 30),
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
                              style:
                                  const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),

                            /// EDIT PROFILE
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfileScreen(),
                                  ),
                                );
                                // Force refresh after a brief delay to ensure backend has updated
                                await Future.delayed(const Duration(milliseconds: 500));
                                fetchProfile();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  "Edit Profile",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold),
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

                      /// ================= ACTIVITIES =================
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
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
                              Icons.star,
                              "My Badges",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyBadgesScreen(),
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
                                    builder: (_) =>
                                        const HelpSupportScreen(),
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
}
