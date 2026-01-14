import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  String? name;
  String? email;
  String? role;
  String? city; // ✅ ADDED

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  /// ✅ UPDATED: Load profile from SharedPreferences "user" first,
  /// fallback to token decoding.
  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString("user");

    if (userStr != null) {
      try {
        final user = jsonDecode(userStr);
        setState(() {
          name = user["name"] ?? "Volunteer";
          email = user["email"] ?? "Not available";
          role = user["role"]?.toString();
          city = user["city"]?.toString(); // ✅ ADDED
        });
        return;
      } catch (_) {
        // fallback to token
      }
    }

    // 2) fallback: decode from token
    final token = await TokenService.getToken();
    if (token == null) return;

    final parts = token.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
    );

    setState(() {
      name = payload["name"] ?? "Volunteer";
      email = payload["email"] ?? "Not available";
      role = payload["role"]?.toString();
      city = payload["city"]?.toString(); // ✅ ADDED (if token has)
    });
  }

  Future<void> logout() async {
    await TokenService.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user");
    await prefs.remove("token"); // ✅ FIX: remove token too

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
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// ================= HEADER =================
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 42),
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

                  /// ✅ City dynamic now
                  Text(
                    (city == null || city!.trim().isEmpty)
                        ? "City not set"
                        : "$city, India",
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 14),

                  /// ✅ EDIT PROFILE (refresh after returning)
                  GestureDetector(
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );

                      if (updated == true) {
                        loadProfile(); // ✅ refresh updated name/city
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 10),
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

            const SizedBox(height: 20),

            /// ================= QUICK STATS =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E6BE6), Color(0xFF2ECC71)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard(
                      icon: Icons.emoji_events,
                      value: "12",
                      label: "Events Completed",
                      color: Colors.orange,
                    ),
                    _statCard(
                      icon: Icons.star,
                      value: "5",
                      label: "Badges Earned",
                      color: Colors.amber,
                    ),
                    _statCard(
                      icon: Icons.account_balance_wallet,
                      value: "₹20,000",
                      label: "Total Earnings",
                      color: Colors.greenAccent,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// ================= ACTIVITIES =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Volunteer Activities",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _activityTile(
                    icon: Icons.assignment,
                    title: "My Applications",
                    badge: "3",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyApplicationsScreen(),
                        ),
                      );
                    },
                  ),

                  _activityTile(
                    icon: Icons.star,
                    title: "My Badges",
                    badge: "5",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyBadgesScreen(),
                        ),
                      );
                    },
                  ),

                  _activityTile(
                    icon: Icons.payments,
                    title: "Payment History",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentHistoryScreen(),
                        ),
                      );
                    },
                  ),

                  _activityTile(
                    icon: Icons.group,
                    title: "Invite Friends",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InviteFriendsScreen(),
                        ),
                      );
                    },
                  ),

                  _activityTile(
                    icon: Icons.help_outline,
                    title: "Help & Support",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  /// ================= LOGOUT =================
                  GestureDetector(
                    onTap: logout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "Logout",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= HELPERS =================
  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _activityTile({
    required IconData icon,
    required String title,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: badge != null
            ? CircleAvatar(
                radius: 12,
                backgroundColor: Colors.green,
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}