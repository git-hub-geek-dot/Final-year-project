import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/user_service.dart';

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
  bool loadingProfile = true;
  
  XFile? _profileImage; // Use XFile instead of File for web compatibility
  Uint8List? _profileImageBytes; // Store bytes for web preview
  String? _profileImageUrl;
  bool isUploadingImage = false;
  bool _hasProfileChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileFromApi();
  }

  // ================= FETCH PROFILE =================
  Future<void> _fetchProfileFromApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        setState(() => loadingProfile = false);
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/profile");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);

        setState(() {
          nameController.text = user["name"] ?? "";
          emailController.text = user["email"] ?? "";
          cityController.text = user["city"] ?? "";
          contactController.text =
              user["contact_number"]?.toString() ?? "";
          _profileImageUrl = user["profile_picture_url"];
          loadingProfile = false;
        });
      } else {
        loadingProfile = false;
      }
    } catch (e) {
      loadingProfile = false;
    }
  }

  // ================= BUILD PROFILE IMAGE PROVIDER =================
  ImageProvider? _buildProfileImageProvider() {
    if (_profileImage != null) {
      if (kIsWeb && _profileImageBytes != null) {
        // On web, use MemoryImage with the bytes for immediate preview
        return MemoryImage(_profileImageBytes!);
      } else if (!kIsWeb) {
        // On mobile, use FileImage
        return FileImage(File(_profileImage!.path));
      }
    }
    
    // Show uploaded image if available
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    
    return null;
  }

  // ================= PICK IMAGE FROM GALLERY =================
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        // Read bytes for preview
        final bytes = await pickedFile.readAsBytes();
        
        setState(() {
          _profileImage = pickedFile;
          _profileImageBytes = bytes; // Store bytes for web preview
        });

        // Upload the image
        await _uploadProfileImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  // ================= UPLOAD PROFILE IMAGE =================
  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;

    setState(() => isUploadingImage = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        setState(() => isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      // Upload image and get URL
      final imageUrl = await UserService.uploadProfilePicture(token, _profileImage!);

      if (imageUrl != null) {
        setState(() {
          _profileImageUrl = imageUrl;
          _hasProfileChanges = true;
          isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated ✅")),
        );
      } else {
        setState(() => isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image")),
        );
      }
    } catch (e) {
      setState(() => isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _removeProfilePicture() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Profile Picture"),
        content: const Text("Are you sure you want to remove your profile picture?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => isUploadingImage = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        setState(() => isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      // Call delete endpoint
      final success = await UserService.deleteProfilePicture(token);

      if (success) {
        setState(() {
          _profileImage = null;
          _profileImageUrl = null;
          _profileImageBytes = null;
          _hasProfileChanges = true;
          isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture removed ✅")),
        );
      } else {
        setState(() => isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to remove picture")),
        );
      }
    } catch (e) {
      setState(() => isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ================= SAVE PROFILE =================
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/profile/update");

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "city": city,
          "contact_number": contact,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        _hasProfileChanges = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated ✅")),
        );

        Navigator.pop(context, true); // 🔁 trigger refresh
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
    return WillPopScope(
      onWillPop: () async {
        if (_hasProfileChanges) {
          Navigator.pop(context, true);
          return false;
        }
        return true;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2E6BE6),
        title: const Text(
          "Edit Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _hasProfileChanges);
          },
        ),
      ),
      body: loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Picture Section
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFFE6E6FA),
                        backgroundImage: _buildProfileImageProvider(),
                        child: (_profileImage == null &&
                                (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 48, color: Colors.deepPurple)
                            : null,
                      ),
                      if (isUploadingImage)
                        Positioned.fill(
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.black54,
                            child: const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: isUploadingImage ? null : _pickImageFromGallery,
                        child: Text(
                          "Change Profile Picture",
                          style: TextStyle(
                            color: isUploadingImage ? Colors.grey : const Color(0xFF2E6BE6),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: isUploadingImage ? null : _removeProfilePicture,
                          child: Text(
                            "Remove",
                            style: TextStyle(
                              color: isUploadingImage ? Colors.grey : Colors.red,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
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
                        color: isLoading
                            ? Colors.grey
                            : const Color(0xFF2ECC71),
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
