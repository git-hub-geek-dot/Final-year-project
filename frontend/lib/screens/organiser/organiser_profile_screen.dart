import 'package:flutter/material.dart';

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
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    borderRadius: BorderRadius.vertical(
      bottom: Radius.circular(40),
    ),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min, // 🔥 IMPORTANT
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

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
    ],
  ),
),

            // 📊 OVERVIEW STATS
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

            // 📋 OPTIONS LIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _profileOption(
                    icon: Icons.assignment,
                    text: "Volunteer Applications",
                  ),
                  _profileOption(
                    icon: Icons.person_add,
                    text: "Invite Friends",
                  ),
                  _profileOption(
                    icon: Icons.help_outline,
                    text: "Help & Support",
                  ),
                  _profileOption(
                    icon: Icons.settings,
                    text: "Settings",
                  ),
                  _profileOption(
                    icon: Icons.logout,
                    text: "Logout",
                    isLogout: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
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
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// 🔹 PROFILE OPTION TILE
Widget _profileOption({
  required IconData icon,
  required String text,
  bool isLogout = false,
}) {
  return Container(
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
  );
}
