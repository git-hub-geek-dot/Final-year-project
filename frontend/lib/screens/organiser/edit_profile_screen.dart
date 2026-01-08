import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController(text: "Ankit Verma");
  final _emailController = TextEditingController(text: "ankit@email.com");
  final _cityController = TextEditingController(text: "Bengaluru");
  final _contactController = TextEditingController(text: "9876543210");
  final _govIdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _contactController.dispose();
    _govIdController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    // 🔗 Later connect backend API here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 20),

            _inputField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline,
            ),
            _inputField(
              controller: _emailController,
              label: "Email",
              icon: Icons.email_outlined,
            ),
            _inputField(
              controller: _cityController,
              label: "City",
              icon: Icons.location_on_outlined,
            ),
            _inputField(
              controller: _contactController,
              label: "Contact Number",
              icon: Icons.phone_outlined,
            ),
            _inputField(
              controller: _govIdController,
              label: "Government ID (Optional)",
              icon: Icons.badge_outlined,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 INPUT FIELD
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
