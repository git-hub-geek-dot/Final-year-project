import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../services/event_service.dart';
import '../../services/token_service.dart';
import '../../config/api_config.dart';
import 'dart:convert';

class OrganiserGetVerifiedScreen extends StatefulWidget {
  const OrganiserGetVerifiedScreen({super.key});

  @override
  State<OrganiserGetVerifiedScreen> createState() =>
      _OrganiserGetVerifiedScreenState();
}

class _OrganiserGetVerifiedScreenState
    extends State<OrganiserGetVerifiedScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _idType;
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _idImage;
  String? _idDocumentUrl;
  XFile? _selfieImage;
  String? _selfieUrl;
  XFile? _eventProofImage;
  String? _eventProofUrl;
  bool loading = false;

  @override
  void dispose() {
    _idNumberController.dispose();
    _orgNameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Get Verified")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Organiser Verification",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ID TYPE
              DropdownButtonFormField<String>(
                value: _idType,
                decoration: const InputDecoration(
                  labelText: "ID Type",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "aadhaar", child: Text("Aadhaar")),
                  DropdownMenuItem(value: "pan", child: Text("PAN Card")),
                  DropdownMenuItem(value: "passport", child: Text("Passport")),
                ],
                onChanged: (value) => setState(() => _idType = value),
                validator: (value) =>
                    value == null ? "Please select ID type" : null,
              ),

              const SizedBox(height: 16),

              // ID NUMBER
              TextFormField(
                controller: _idNumberController,
                decoration: const InputDecoration(
                  labelText: "ID Number",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter ID number";
                  }
                  if (value.length < 5) {
                    return "Invalid ID number";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Upload ID proof (required)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(_idImage == null ? "Upload ID Proof *" : "ID Selected"),
                      onPressed: () async {
                        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                        if (picked != null) {
                          final size = await picked.length();
                          const maxBytes = 5 * 1024 * 1024;
                          if (size > maxBytes) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File too large (max 5MB)")));
                            return;
                          }
                          setState(() => _idImage = picked);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading ID proof...")));
                          try {
                            final url = await EventService.uploadImage(picked);
                            setState(() => _idDocumentUrl = url);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID proof uploaded")));
                          } catch (e) {
                            setState(() { _idImage = null; _idDocumentUrl = null; });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
                          }
                        }
                      },
                    ),
                  ),
                  if (_idDocumentUrl != null) const SizedBox(width: 8),
                  if (_idDocumentUrl != null) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),

              const SizedBox(height: 16),

              // Upload selfie with ID (required)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_selfieImage == null ? "Upload Selfie with ID *" : "Selfie Selected"),
                      onPressed: () async {
                        XFile? picked;
                        try {
                          picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
                        } catch (_) {
                          picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                        }
                        if (picked != null) {
                          final size = await picked.length();
                          const maxBytes = 5 * 1024 * 1024;
                          if (size > maxBytes) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File too large (max 5MB)")));
                            return;
                          }
                          setState(() => _selfieImage = picked);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading selfie...")));
                          try {
                            final url = await EventService.uploadImage(picked);
                            setState(() => _selfieUrl = url);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selfie uploaded")));
                          } catch (e) {
                            setState(() { _selfieImage = null; _selfieUrl = null; });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
                          }
                        }
                      },
                    ),
                  ),
                  if (_selfieUrl != null) const SizedBox(width: 8),
                  if (_selfieUrl != null) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),

              const SizedBox(height: 20),
              const Text(
                "Organisation Details",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // ORGANISATION NAME
              TextFormField(
                controller: _orgNameController,
                decoration: const InputDecoration(
                  labelText: "Organisation Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty
                        ? "Enter organisation name"
                        : null,
              ),

              const SizedBox(height: 16),

              // Event proof (optional)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(_eventProofImage == null ? "Upload Event Proof / Certificate" : "Proof Selected"),
                      onPressed: () async {
                        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                        if (picked != null) {
                          final size = await picked.length();
                          const maxBytes = 5 * 1024 * 1024;
                          if (size > maxBytes) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File too large (max 5MB)")));
                            return;
                          }
                          setState(() => _eventProofImage = picked);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading event proof...")));
                          try {
                            final url = await EventService.uploadImage(picked);
                            setState(() => _eventProofUrl = url);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event proof uploaded")));
                          } catch (e) {
                            setState(() { _eventProofImage = null; _eventProofUrl = null; });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
                          }
                        }
                      },
                    ),
                  ),
                  if (_eventProofUrl != null) const SizedBox(width: 8),
                  if (_eventProofUrl != null) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),

              const SizedBox(height: 16),

              // WEBSITE / SOCIAL LINK
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: "Website / Social Link",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (!_formKey.currentState!.validate()) return;

                    // require id proof and selfie
                    if (_idDocumentUrl == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload ID proof")));
                      return;
                    }
                    if (_selfieUrl == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload selfie with ID")));
                      return;
                    }

                    setState(() => loading = true);

                    final token = await TokenService.getToken();
                    if (token == null || token.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login again")));
                      setState(() => loading = false);
                      return;
                    }

                    try {
                      final res = await http.post(
                        Uri.parse("${ApiConfig.baseUrl}/verification/request"),
                        headers: {
                          "Content-Type": "application/json",
                          "Authorization": "Bearer $token",
                        },
                        body: jsonEncode({
                          "role": "organiser",
                          "idType": _idType,
                          "idNumber": _idNumberController.text.trim(),
                          "idDocumentUrl": _idDocumentUrl,
                          "selfieUrl": _selfieUrl,
                          "organisationName": _orgNameController.text.trim(),
                          "eventProofUrl": _eventProofUrl,
                          "websiteLink": _linkController.text.trim(),
                        }),
                      );

                      if (res.statusCode == 201 || res.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification request submitted")));
                        Navigator.pop(context);
                      } else {
                        final data = jsonDecode(res.body);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data["message"] ?? "Submission failed")));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    } finally {
                      setState(() => loading = false);
                    }
                  },
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Submit for Verification"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _uploadTile({required IconData icon, required String title}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.add),
        onTap: () {
          // image picker later
        },
      ),
    );
  }
}
