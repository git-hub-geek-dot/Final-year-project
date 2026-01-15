import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart'; // ✅ ADD THIS
import '../../services/token_service.dart';
import 'account_settings_screen.dart';
import 'help_support_screen.dart';
import 'about_volunteerx_screen.dart';
import 'edit_profile_screen.dart';

class OrganiserProfileScreen extends StatelessWidget {
  const OrganiserProfileScreen({super.key});

  /// ✅ DEACTIVATE ACCOUNT FUNCTION (Soft delete)
  Future<void> handleDeactivateAccount(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Get token
    final token = prefs.getString('token');

    debugPrint("DEACTIVATE TOKEN: $token");
    debugPrint("DEACTIVATE URL: ${ApiConfig.baseUrl}/account/deactivate");

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Token not found. Please login again.")),
      );
      return;
    }

    // ✅ confirmation
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

    // ✅ loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // ✅ FIX: use ApiConfig (works on Web + Android)
      final response = await http
          .put(
            Uri.parse("${ApiConfig.baseUrl}/account/deactivate"),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5)); // ✅ fast fail

      Navigator.pop(context); // close loader

      debugPrint("DEACTIVATE STATUS: ${response.statusCode}");
      debugPrint("DEACTIVATE BODY: ${response.body}");

      if (response.statusCode == 200) {
        // ✅ clear session
        await prefs.clear();
        await TokenService.clearToken();

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deactivated ✅")),
        );

        // ✅ redirect to login screen
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
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Volunteerx",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.notifications, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Ankit Verma",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Bengaluru, India",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
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
                    icon: Icons.manage_accounts,
                    text: "Account Settings",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountSettingsScreen(),
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
                          builder: (_) => const HelpSupportScreen(),
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
                          builder: (_) => const AboutVolunteerxScreen(),
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
                    onTap: () => handleDeactivateAccount(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 PROFILE OPTION TILE
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
                color: (isLogout || isDelete) ? Colors.red : Colors.black,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    ),
  );
}