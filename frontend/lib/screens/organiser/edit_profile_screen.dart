import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../services/event_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _contactController = TextEditingController();
  final _govIdController = TextEditingController();

  bool loading = false;
  String? _profilePictureUrl;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) return;

      final resp = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _nameController.text = data["name"] ?? "";
        _emailController.text = data["email"] ?? "";
        _cityController.text = data["city"] ?? "";
        _contactController.text = data["contact_number"] ?? "";
        _govIdController.text = data["government_id"] ?? "";
        _profilePictureUrl = data["profile_picture_url"];
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _contactController.dispose();
    _govIdController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    try {
      setState(() => loading = true);

      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception("Token missing. Please login again.");
      }

      // If user selected a new image, upload it first
      String? uploadedUrl = _profilePictureUrl;
      if (_selectedImage != null) {
        uploadedUrl = await EventService.uploadImage(_selectedImage!);
      }

      // Use authenticated profile update endpoint
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/profile/update"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "city": _cityController.text.trim(),
          "contact_number": _contactController.text.trim(),
          "government_id": _govIdController.text.trim(),
          "profile_picture_url": uploadedUrl,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(data["message"] ?? data["error"] ?? "Update failed");
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully ✅")),
      );

      Navigator.pop(context, true); // 🔥 tells profile screen to refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
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
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _selectedImage != null
                      ? (kIsWeb
                          ? NetworkImage(_selectedImage!.path) as ImageProvider
                          : FileImage(File(_selectedImage!.path)))
                      : (_profilePictureUrl != null
                          ? NetworkImage(_profilePictureUrl!)
                          : null),
                  child: (_selectedImage == null && _profilePictureUrl == null)
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.black54),
                  onPressed: () async {
                    final picked = await _picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) setState(() => _selectedImage = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            _input(_nameController, "Full Name", Icons.person),
            _input(_emailController, "Email", Icons.email),
            _input(_cityController, "City", Icons.location_on),
            _input(_contactController, "Contact Number", Icons.phone),
            _input(_govIdController, "Government ID (Optional)", Icons.badge),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
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
