import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
  bool loadingProfile = true;
  XFile? _selectedImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfileFromApi();
  }

  // ================= BUILD PROFILE IMAGE PROVIDER =================
  ImageProvider? _buildProfileImageProvider() {
    if (_selectedImage != null) {
      if (kIsWeb) {
        // Web: Use NetworkImage with data URL or object URL
        return NetworkImage(_selectedImage!.path);
      } else {
        // Mobile: Use FileImage
        return FileImage(File(_selectedImage!.path));
      }
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
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

  // ================= SHOW IMAGE SOURCE OPTIONS =================
  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Image",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFF2E6BE6)),
                title: const Text("Choose from Gallery"),
                subtitle: const Text("Select from your photos"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ================= PICK IMAGE FROM GALLERY =================
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  // ================= UPLOAD IMAGE TO SERVER =================
  Future<String?> _uploadProfileImage() async {
    if (_selectedImage == null) {
      return _profileImageUrl; // Return existing URL if no new image
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        print("Token is empty");
        return null;
      }

      print("Starting image upload...");
      print("Image path: ${_selectedImage!.path}");

      // Read the image bytes
      final imageBytes = await _selectedImage!.readAsBytes();
      print("Image bytes read: ${imageBytes.length} bytes");

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiConfig.baseUrl}/upload"),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add file to request
      final filename = _selectedImage!.name ?? 'image.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );

      print("Sending request to: ${ApiConfig.baseUrl}/upload");
      print("File field name: 'image'");
      print("File name: $filename");
      print("File size: ${imageBytes.length} bytes");

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final imageUrl = jsonData['url'];
        print("✅ Image uploaded successfully!");
        print("Image URL: $imageUrl");
        return imageUrl;
      } else {
        print("❌ Upload failed: ${response.statusCode}");
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: ${response.body}")),
        );
        return null;
      }
    } catch (e) {
      print("❌ Error uploading image: $e");
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error: $e")),
      );
      return null;
    }
  }

  // ================= REMOVE PROFILE PICTURE =================
  Future<void> _removeProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Token not found. Please login again.")),
        );
        return;
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/profile/picture");

      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("Remove picture response status: ${response.statusCode}");
      print("Remove picture response: ${response.body}");

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _profileImageUrl = null;
          _selectedImage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture removed ✓")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to remove picture: ${response.body}")),
        );
      }
    } catch (e) {
      print("Error removing picture: $e");
      if (!mounted) return;
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
      // Upload image if selected
      String? profileImageUrl = _profileImageUrl;
      if (_selectedImage != null) {
        print("Image selected, uploading...");
        profileImageUrl = await _uploadProfileImage();
        if (profileImageUrl == null) {
          setState(() => isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload image")),
          );
          return;
        }
        print("Image uploaded, URL: $profileImageUrl");
      }

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
      
      final body = jsonEncode({
        "name": name,
        "city": city,
        "contact_number": contact,
        "profile_picture_url": profileImageUrl,
      });

      print("Sending profile update...");
      print("URL: $url");
      print("Body: $body");

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: body,
      );

      print("Profile update response status: ${response.statusCode}");
      print("Profile update response: ${response.body}");

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;

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
      print("Error saving profile: $e");
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
      body: loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  /// ================= PROFILE PICTURE =================
                  GestureDetector(
                    onTap: _showImageSourceOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFE6E6FA),
                          backgroundImage: _buildProfileImageProvider(),
                          child: _selectedImage == null &&
                                  (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 48, color: Colors.deepPurple)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E6BE6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedImage != null ? "Image selected ✓" : "Tap to take photo or choose from gallery",
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedImage != null ? Colors.green : Colors.grey,
                    ),
                  ),
                  // Show remove button only if image exists
                  if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty && _selectedImage == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: _removeProfilePicture,
                        child: Text(
                          "Remove picture",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
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
