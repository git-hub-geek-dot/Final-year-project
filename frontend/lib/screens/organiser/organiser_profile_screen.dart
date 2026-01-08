import 'package:flutter/material.dart';
import '../../services/token_service.dart';
import 'leaderboard_screen.dart';
import 'account_settings_screen.dart';
import 'help_support_screen.dart';
import 'about_volunteerx_screen.dart';
import 'edit_profile_screen.dart'; // ✅ ADDED

class OrganiserProfileScreen extends StatelessWidget {
  const OrganiserProfileScreen({super.key});

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

                  // ✅ EDIT PROFILE BUTTON (FIXED)
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

            const SizedBox(height: 16),

            // 📊 STATS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _StatItem("9", "Events Posted"),
                    _StatItem("82", "Volunteers Hired"),
                    _StatItem("26", "Requests Pending"),
                  ],
                ),
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
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),

      // 🔻 BOTTOM NAVIGATION
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
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: "Leaderboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

/// 🔹 STAT ITEM
class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 🔹 PROFILE OPTION TILE
Widget _profileOption({
  required BuildContext context,
  required IconData icon,
  required String text,
  bool isLogout = false,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: () async {
      if (isLogout) {
        await TokenService.clearToken();
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
          Icon(icon, color: isLogout ? Colors.red : Colors.grey),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isLogout ? Colors.red : Colors.black,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    ),
  );
}
