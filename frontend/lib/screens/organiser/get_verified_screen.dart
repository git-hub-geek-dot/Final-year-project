import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../localization/localization_extensions.dart';
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

  Future<void> _pickAndUpload({
    required ImageSource source,
    required ValueSetter<XFile?> setImage,
    required ValueSetter<String?> setUrl,
    required String uploadingKey,
    required String successKey,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final size = await picked.length();
    const maxBytes = 5 * 1024 * 1024;
    if (size > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("File too large (max 5MB)"))),
      );
      return;
    }

    setState(() => setImage(picked));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(uploadingKey))),
    );

    try {
      final url = await EventService.uploadImage(picked);
      if (!mounted) return;
      setState(() => setUrl(url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(successKey))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        setImage(null);
        setUrl(null);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Upload failed: {error}", args: {"error": e.toString()}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_verificationStatus ?? "").toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Get Verified"))),
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
            Text(
              context.tr("Your account is already verified."),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr("You do not need to submit verification again."),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr("Back to Profile")),
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
            Text(
              context.tr("Your verification request is under review."),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                "You cannot submit another request until the current one is reviewed.",
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr("Back to Profile")),
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
                child: Text(
                  context.tr(
                    "Your previous verification request was rejected. Please review your details and submit again.",
                  ),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              context.tr("Organiser Verification"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _idType,
              decoration: InputDecoration(
                labelText: context.tr("ID Type"),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: "aadhaar",
                  child: Text(context.tr("Aadhaar")),
                ),
                DropdownMenuItem(
                  value: "pan",
                  child: Text(context.tr("PAN Card")),
                ),
                DropdownMenuItem(
                  value: "passport",
                  child: Text(context.tr("Passport")),
                ),
              ],
              onChanged: (value) => setState(() => _idType = value),
              validator: (value) =>
                  value == null ? context.tr("Please select ID type") : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idNumberController,
              decoration: InputDecoration(
                labelText: context.tr("ID Number"),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr("Enter ID number");
                }
                if (value.length < 5) {
                  return context.tr("Invalid ID number");
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
                      _idImage == null
                          ? context.tr("Upload ID Proof *")
                          : context.tr("ID Selected"),
                    ),
                    onPressed: () => _pickAndUpload(
                      source: ImageSource.gallery,
                      setImage: (value) => _idImage = value,
                      setUrl: (value) => _idDocumentUrl = value,
                      uploadingKey: "Uploading ID proof...",
                      successKey: "ID proof uploaded",
                    ),
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
                          ? context.tr("Upload Selfie with ID *")
                          : context.tr("Selfie Selected"),
                    ),
                    onPressed: () async {
                      try {
                        await _pickAndUpload(
                          source: ImageSource.camera,
                          setImage: (value) => _selfieImage = value,
                          setUrl: (value) => _selfieUrl = value,
                          uploadingKey: "Uploading selfie...",
                          successKey: "Selfie uploaded",
                        );
                      } catch (_) {
                        await _pickAndUpload(
                          source: ImageSource.gallery,
                          setImage: (value) => _selfieImage = value,
                          setUrl: (value) => _selfieUrl = value,
                          uploadingKey: "Uploading selfie...",
                          successKey: "Selfie uploaded",
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
            Text(
              context.tr("Organisation Details"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _orgNameController,
              decoration: InputDecoration(
                labelText: context.tr("Organisation Name"),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? context.tr("Enter organisation name")
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
                          ? context.tr("Upload Event Proof / Certificate")
                          : context.tr("Proof Selected"),
                    ),
                    onPressed: () => _pickAndUpload(
                      source: ImageSource.gallery,
                      setImage: (value) => _eventProofImage = value,
                      setUrl: (value) => _eventProofUrl = value,
                      uploadingKey: "Uploading event proof...",
                      successKey: "Event proof uploaded",
                    ),
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
              decoration: InputDecoration(
                labelText: context.tr("Website / Social Link"),
                border: const OutlineInputBorder(),
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
                            SnackBar(
                              content: Text(context.tr("Please upload ID proof")),
                            ),
                          );
                          return;
                        }
                        if (_selfieUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr("Please upload selfie with ID"),
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => loading = true);

                        final token = await TokenService.getToken();
                        if (token == null || token.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.tr("Please login again")),
                            ),
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
                              SnackBar(
                                content: Text(
                                  context.tr("Verification request submitted"),
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          } else {
                            final data = jsonDecode(res.body);
                            final message =
                                (data["message"] ??
                                        context.tr("Submission failed"))
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
                            SnackBar(
                              content: Text(
                                context.tr(
                                  "Error: {error}",
                                  args: {"error": e.toString()},
                                ),
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => loading = false);
                          }
                        }
                      },
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(context.tr("Submit for Verification")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
