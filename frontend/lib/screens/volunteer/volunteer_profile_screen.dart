import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/token_service.dart';
import '../auth/login_screen.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  String? name;
  String? email;
  String? role;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final token = await TokenService.getToken();
    if (token == null) return;

    final parts = token.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
    );

    setState(() {
      name = payload["name"] ?? "Volunteer";
      email = payload["email"] ?? "Not available";
      role = payload["role"];
    });
  }

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
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 16),

            Text(
              name ?? "",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              email ?? "",
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text("My Applications"),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Applications coming soon"),
                  ),
                );
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(color: Colors.red),
              ),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }
}
