import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/config/api_config.dart';
import '../../services/token_service.dart';
import '../auth/login_screen.dart';

import 'edit_profile_screen.dart';
import 'my_applications_screen.dart';
import 'my_badges_screen.dart';
import 'payment_history_screen.dart';
import 'invite_friends_screen.dart';
import 'help_support_screen.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  bool loading = true;
  String? errorMessage;

  String? name;
  String? email;
  String? city;
  String? role;
  String? profilePictureUrl;

  @override
  void initState() {
    super.initState();
    fetchProfile();
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

      /// 🔴 THIS IS THE IMPORTANT BASEURL LINE
      final url = Uri.parse("${ApiConfig.baseUrl}/profile");


      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("PROFILE STATUS => ${response.statusCode}");
      print("PROFILE BODY => ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          name = data["name"];
          email = data["email"];
          city = data["city"];
          role = data["role"];
          profilePictureUrl = data["profile_picture_url"];
          loading = false;
        });
        print("✅ Profile loaded successfully");
        print("Profile picture URL: $profilePictureUrl");
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
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              backgroundImage: profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                                  ? NetworkImage(profilePictureUrl!)
                                  : null,
                              child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                                  ? const Icon(Icons.person, size: 42)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              name ?? "",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfileScreen(),
                                  ),
                                );

                                if (updated == true) {
                                  fetchProfile(); // 🔁 refresh
                                }
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
                            _tile(Icons.logout, "Logout", logout,
                                color: Colors.red),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
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
