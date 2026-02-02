import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';
import 'account_settings_screen.dart';
import 'help_support_screen.dart';
import 'about_volunteerx_screen.dart';
import 'edit_profile_screen.dart';
import 'get_verified_screen.dart';
import 'leaderboard_screen.dart';
<<<<<<< HEAD
import 'organiser_activity_screen.dart';

=======
import 'my_events_screen.dart';
>>>>>>> 967aa70e5ed64bd61653889365519a10808ddf2e

class OrganiserProfileScreen extends StatefulWidget {
  const OrganiserProfileScreen({super.key});

  @override
  State<OrganiserProfileScreen> createState() =>
      _OrganiserProfileScreenState();
}

class _OrganiserProfileScreenState extends State<OrganiserProfileScreen> {
  bool loading = true;
  String? errorMessage;

  String? name;
  String? email;
  String? city;
  String? role;
  String? profilePictureUrl;
  String? verificationStatus;

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
          "Content-Type": "application/json"
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          profilePictureUrl = data["profile_picture_url"];
          role = data["role"];
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

  Future<void> handleDeactivateAccount(BuildContext context) async {
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
        title: const Text("Deactivate Account"),
        content: const Text(
          "Are you sure you want to deactivate your account?\n\nYour data will remain saved, but you will not be able to login again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Deactivate",
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

      Navigator.pop(context);

      if (response.statusCode == 200) {
        await prefs.clear();
        await TokenService.clearToken();

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deactivated ✅")),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      } else {
        String msg = "Deactivate failed";
        try {
          final data = jsonDecode(response.body);
          msg = data["message"] ?? data["error"] ?? msg;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      // 🔷 HEADER
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  "Volunteerx",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(Icons.notifications,
                                    color: Colors.white),
                              ],
                            ),
                            const SizedBox(height: 20),
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white,
                              backgroundImage: profilePictureUrl != null
                                  ? NetworkImage(profilePictureUrl!)
                                  : null,
                              child: profilePictureUrl == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfileScreen(),
                                  ),
                                );

                                if (updated == true) {
                                  fetchProfile();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "Edit Profile",
                                  style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 📋 OPTIONS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _profileOption(
                              context: context,
                              icon: Icons.event,
                              text: "My Events",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyEventsScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.manage_accounts,
                              text: "Account Settings",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AccountSettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.verified,
                              text: verificationStatus == "pending"
                                  ? "Verification Under Review"
                                  : verificationStatus == "approved"
                                      ? "Verified"
                                      : "Get Verified",
                              onTap: verificationStatus == "pending" ||
                                      verificationStatus == "approved"
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const OrganiserGetVerifiedScreen(),
                                        ),
                                      );
                                    },
                            ),
                            _profileOption(
  context: context,
  icon: Icons.dashboard,
  text: "Organisation Activity",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganiserActivityScreen(),
      ),
    );
  },
),

                            _profileOption(
                              context: context,
                              icon: Icons.help_outline,
                              text: "Help & Support",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const HelpSupportScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.info_outline,
                              text: "About Volunteerx",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AboutVolunteerxScreen(),
                                  ),
                                );
                              },
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.logout,
                              text: "Logout",
                              isLogout: true,
                            ),
                            _profileOption(
                              context: context,
                              icon: Icons.delete_forever,
                              text: "Delete Account",
                              isDelete: true,
                              onTap: () =>
                                  handleDeactivateAccount(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/organiser-home');
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LeaderboardScreen(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: "Leaderboard"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

Widget _profileOption({
  required BuildContext context,
  required IconData icon,
  required String text,
  bool isLogout = false,
  bool isDelete = false,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: () async {
      if (isLogout) {
        await TokenService.clearToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      } else {
        onTap?.call();
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
      child: Row(
        children: [
          Icon(
            icon,
            color: (isLogout || isDelete) ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: (isLogout || isDelete)
                    ? Colors.red
                    : Colors.black,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    ),
  );
}
