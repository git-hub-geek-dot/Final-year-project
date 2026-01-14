import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedProfile(); // ✅ auto fill from saved user
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString("user");

    if (userStr != null) {
      try {
        final user = jsonDecode(userStr);

        setState(() {
          nameController.text = user["name"] ?? "";
          emailController.text = user["email"] ?? "";
          cityController.text = user["city"] ?? "";
          contactController.text =
              user["contact_number"]?.toString() ?? user["contact"]?.toString() ?? "";
        });
      } catch (_) {
        // If invalid JSON ignore
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = nameController.text.trim();
    final city = cityController.text.trim();
    final contact = contactController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name cannot be empty")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ GET TOKEN FROM SHARED PREFERENCES
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      // ✅ Flutter Web: use 127.0.0.1 instead of localhost
      final url = Uri.parse("http://127.0.0.1:4000/api/profile/update");

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": name,
          "city": city,
          "contact_number": contact,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedUser = data["user"] ?? data;

        // ✅ Save updated user locally so Profile Screen can show updated name
        await prefs.setString("user", jsonEncode(updatedUser));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated ✅")),
        );

        // ✅ Auto refresh trigger
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: ${response.body}")),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    cityController.dispose();
    contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2E6BE6),
        title: const Text(
          "Edit Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFFE6E6FA),
              child: Icon(Icons.person, size: 48, color: Colors.deepPurple),
            ),
            const SizedBox(height: 30),

            _inputField(
              label: "Full Name",
              icon: Icons.person,
              controller: nameController,
            ),

            _inputField(
              label: "Email",
              icon: Icons.email,
              controller: emailController,
              enabled: false,
            ),

            _inputField(
              label: "City (Optional)",
              icon: Icons.location_on,
              controller: cityController,
            ),

            _inputField(
              label: "Contact Number (Optional)",
              icon: Icons.phone,
              controller: contactController,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 30),

            GestureDetector(
              onTap: isLoading ? null : _saveChanges,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isLoading ? Colors.grey : const Color(0xFF2ECC71),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    isLoading ? "Saving..." : "Save Changes",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}