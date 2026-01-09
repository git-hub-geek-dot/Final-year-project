import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController nameController =
      TextEditingController(text: "Ankit Verma");
  final TextEditingController emailController =
      TextEditingController(text: "ankit@email.com");
  final TextEditingController cityController =
      TextEditingController(text: "Bengaluru");
  final TextEditingController contactController =
      TextEditingController(text: "9876543210");

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
            /// Avatar
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
              enabled: false, // email usually not editable
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

            /// Save Button (UI only)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text("Profile update will be available soon"),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    "Save Changes",
                    style: TextStyle(
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

  /// ================= INPUT FIELD =================
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
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
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14),
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
