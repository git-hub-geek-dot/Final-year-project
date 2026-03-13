import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/event_service.dart';
import '../../services/token_service.dart';
import '../../services/verification_service.dart';

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
  bool _checkingStatus = true;
  String? _verificationStatus;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _orgNameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final status = await VerificationService.getStatus();
      if (!mounted) return;
      setState(() {
        _verificationStatus = status?.toLowerCase();
        _checkingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verificationStatus = null;
        _checkingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_verificationStatus ?? "").toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text("Get Verified")),
      body: _checkingStatus
          ? const Center(child: CircularProgressIndicator())
          : status == "approved"
              ? _buildApprovedState()
              : status == "pending"
                  ? _buildPendingState()
                  : _buildForm(status),
    );
  }

  Widget _buildApprovedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified,
              color: Colors.green,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              "Your account is already verified.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "You do not need to submit verification again.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back to Profile"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.orange,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              "Your verification request is under review.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "You cannot submit another request until the current one is reviewed.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back to Profile"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(String status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status == "rejected") ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: const Text(
                  "Your previous verification request was rejected. Please review your details and submit again.",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              "Organiser Verification",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _idType,
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _idImage == null ? "Upload ID Proof *" : "ID Selected",
                    ),
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                        maxWidth: 1600,
                      );
                      if (picked == null) return;

                      final size = await picked.length();
                      const maxBytes = 5 * 1024 * 1024;
                      if (size > maxBytes) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("File too large (max 5MB)"),
                          ),
                        );
                        return;
                      }

                      setState(() => _idImage = picked);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Uploading ID proof...")),
                      );
                      try {
                        final url = await EventService.uploadImage(picked);
                        if (!mounted) return;
                        setState(() => _idDocumentUrl = url);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("ID proof uploaded")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _idImage = null;
                          _idDocumentUrl = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Upload failed: $e")),
                        );
                      }
                    },
                  ),
                ),
                if (_idDocumentUrl != null) const SizedBox(width: 8),
                if (_idDocumentUrl != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _selfieImage == null
                          ? "Upload Selfie with ID *"
                          : "Selfie Selected",
                    ),
                    onPressed: () async {
                      XFile? picked;
                      try {
                        picked = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                          maxWidth: 1600,
                        );
                      } catch (_) {
                        picked = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                          maxWidth: 1600,
                        );
                      }
                      if (picked == null) return;

                      final size = await picked.length();
                      const maxBytes = 5 * 1024 * 1024;
                      if (size > maxBytes) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("File too large (max 5MB)"),
                          ),
                        );
                        return;
                      }

                      setState(() => _selfieImage = picked);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Uploading selfie...")),
                      );
                      try {
                        final url = await EventService.uploadImage(picked);
                        if (!mounted) return;
                        setState(() => _selfieUrl = url);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Selfie uploaded")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _selfieImage = null;
                          _selfieUrl = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Upload failed: $e")),
                        );
                      }
                    },
                  ),
                ),
                if (_selfieUrl != null) const SizedBox(width: 8),
                if (_selfieUrl != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Organisation Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _orgNameController,
              decoration: const InputDecoration(
                labelText: "Organisation Name",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? "Enter organisation name"
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _eventProofImage == null
                          ? "Upload Event Proof / Certificate"
                          : "Proof Selected",
                    ),
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                        maxWidth: 1600,
                      );
                      if (picked == null) return;

                      final size = await picked.length();
                      const maxBytes = 5 * 1024 * 1024;
                      if (size > maxBytes) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("File too large (max 5MB)"),
                          ),
                        );
                        return;
                      }

                      setState(() => _eventProofImage = picked);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Uploading event proof..."),
                        ),
                      );
                      try {
                        final url = await EventService.uploadImage(picked);
                        if (!mounted) return;
                        setState(() => _eventProofUrl = url);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Event proof uploaded")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _eventProofImage = null;
                          _eventProofUrl = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Upload failed: $e")),
                        );
                      }
                    },
                  ),
                ),
                if (_eventProofUrl != null) const SizedBox(width: 8),
                if (_eventProofUrl != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
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
                onPressed: loading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;

                        if (_idDocumentUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please upload ID proof"),
                            ),
                          );
                          return;
                        }
                        if (_selfieUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please upload selfie with ID"),
                            ),
                          );
                          return;
                        }

                        setState(() => loading = true);

                        final token = await TokenService.getToken();
                        if (token == null || token.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please login again")),
                          );
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

                          if (!mounted) return;

                          if (res.statusCode == 201 || res.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Verification request submitted"),
                              ),
                            );
                            Navigator.pop(context);
                          } else {
                            final data = jsonDecode(res.body);
                            final message =
                                (data["message"] ?? "Submission failed")
                                    .toString();
                            if (message.toLowerCase().contains(
                              "already verified",
                            )) {
                              setState(() => _verificationStatus = "approved");
                            } else if (message.toLowerCase().contains(
                              "under review",
                            )) {
                              setState(() => _verificationStatus = "pending");
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => loading = false);
                          }
                        }
                      },
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit for Verification"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
