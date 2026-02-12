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
  final TextEditingController skillsController = TextEditingController();
  final TextEditingController interestsController = TextEditingController();

  final List<String> _skills = [];
  final List<String> _interests = [];

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
    _fetchPreferences();
  }

  Future<void> _fetchPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/volunteer/dashboard");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final skills = (data["skills"] as List?)
                ?.map((s) => s.toString())
                .toList() ??
            [];
        final interests = (data["interests"] as List?)
                ?.map((s) => s.toString())
                .toList() ??
            [];

        setState(() {
          _skills
            ..clear()
            ..addAll(skills);
          _interests
            ..clear()
            ..addAll(interests);
          skillsController.clear();
          interestsController.clear();
        });
      }
    } catch (_) {
      // Keep fields empty on error.
    }
  }

  void _addItem(
    TextEditingController controller,
    List<String> items,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final exists = items.any(
      (item) => item.toLowerCase() == text.toLowerCase(),
    );
    if (exists) {
      controller.clear();
      return;
    }

    setState(() {
      items.add(text);
      controller.clear();
      _hasProfileChanges = true;
    });
  }

  void _removeItem(List<String> items, String value) {
    setState(() {
      items.remove(value);
      _hasProfileChanges = true;
    });
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
          _profileImageUrl =
              _normalizeProfileImageUrl(user["profile_picture_url"]?.toString());
          loadingProfile = false;
        });
      } else {
        loadingProfile = false;
      }
    } catch (e) {
      loadingProfile = false;
    }
  }

  String? _normalizeProfileImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        "${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}";

    if (url.startsWith("/uploads/")) {
      return "$origin$url";
    }

    if (url.startsWith("uploads/")) {
      return "$origin/$url";
    }

    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.hasScheme) {
      if (ApiConfig.useCloud) {
        return url;
      }

      final host = parsed.host;
      final isLocalLike = host == "localhost" ||
          host == "127.0.0.1" ||
          host.startsWith("10.") ||
          host.startsWith("192.168.") ||
          host.startsWith("172.");

      if (isLocalLike && host != baseUri.host) {
        final pathWithQuery =
            parsed.hasQuery ? "${parsed.path}?${parsed.query}" : parsed.path;
        return "$origin$pathWithQuery";
      }
    }

    return url;
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
    final normalizedUrl = _normalizeProfileImageUrl(_profileImageUrl);
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return NetworkImage(normalizedUrl);
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

  Future<bool> _savePreferences(String token) async {
    try {
      final skills = <String>[..._skills];
      final interests = <String>[..._interests];

      final pendingSkill = skillsController.text.trim();
      if (pendingSkill.isNotEmpty &&
          !skills.any((s) => s.toLowerCase() == pendingSkill.toLowerCase())) {
        skills.add(pendingSkill);
      }

      final pendingInterest = interestsController.text.trim();
      if (pendingInterest.isNotEmpty &&
          !interests.any(
            (s) => s.toLowerCase() == pendingInterest.toLowerCase(),
          )) {
        interests.add(pendingInterest);
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/volunteer/preferences");
      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "skills": skills,
          "interests": interests,
        }),
      );

      if (response.statusCode == 200) {
        _hasProfileChanges = true;
        return true;
      }
    } catch (_) {
      return false;
    }

    return false;
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
          "profile_picture_url": _profileImageUrl,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _hasProfileChanges = true;

        final preferencesSaved = await _savePreferences(token);

        if (!mounted) return;
        setState(() => isLoading = false);

        if (!preferencesSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated, but preferences failed")),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated ✅")),
        );

        Navigator.pop(context, true); // 🔁 trigger refresh
      } else {
        setState(() => isLoading = false);
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
    skillsController.dispose();
    interestsController.dispose();
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
                        onBackgroundImageError: (_profileImage == null &&
                                (_profileImageUrl?.isNotEmpty ?? false))
                            ? (_, __) {
                                if (!mounted || _profileImageUrl == null) {
                                  return;
                                }
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted || _profileImageUrl == null) {
                                    return;
                                  }
                                  setState(() => _profileImageUrl = null);
                                });
                              }
                            : null,
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

                  _chipInputField(
                    label: "Skills",
                    icon: Icons.auto_awesome,
                    controller: skillsController,
                    items: _skills,
                    hintText: "Add skill",
                    onAdd: () => _addItem(skillsController, _skills),
                    onRemove: (value) => _removeItem(_skills, value),
                  ),

                  _chipInputField(
                    label: "Interests",
                    icon: Icons.favorite_border,
                    controller: interestsController,
                    items: _interests,
                    hintText: "Add interest",
                    onAdd: () => _addItem(interestsController, _interests),
                    onRemove: (value) => _removeItem(_interests, value),
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

  Widget _chipInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required List<String> items,
    required String hintText,
    required VoidCallback onAdd,
    required void Function(String value) onRemove,
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
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              hintText: hintText,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              "No items added",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => InputChip(
                      label: Text(item),
                      onDeleted: () => onRemove(item),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
