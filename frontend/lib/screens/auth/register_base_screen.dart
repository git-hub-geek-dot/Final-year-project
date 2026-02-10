import 'login_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

abstract class RegisterBaseScreen extends StatefulWidget {
  const RegisterBaseScreen({super.key});

  String get role;
  bool get showOrganiserFields => false;
  bool get showVolunteerFields => false;

  @override
  State<RegisterBaseScreen> createState() => _RegisterBaseScreenState();
}

class _RegisterBaseScreenState extends State<RegisterBaseScreen> {
  static const bool enablePhoneOtp = false;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final emailOtpController = TextEditingController();
  final phoneOtpController = TextEditingController();

  final contactController = TextEditingController();
  final cityController = TextEditingController();
  final govIdController = TextEditingController();

  bool loading = false;
  bool sendingOtp = false;
  bool verifyingOtp = false;
  bool emailOtpSent = false;
  bool emailVerified = false;
  bool sendingPhoneOtp = false;
  bool verifyingPhoneOtp = false;
  bool phoneOtpSent = false;
  bool phoneVerified = false;
  String? phoneVerificationId;
  bool _obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    emailOtpController.dispose();
    phoneOtpController.dispose();
    contactController.dispose();
    cityController.dispose();
    govIdController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showError("Name, email and password are required");
      return;
    }

    if (widget.role == "organiser" &&
        contactController.text.trim().isEmpty) {
      showError("Contact number is required for organiser");
      return;
    }

    if (!emailVerified) {
      showError("Please verify your email");
      return;
    }

    final phoneValue = contactController.text.trim();
    if (enablePhoneOtp && phoneValue.isNotEmpty && !phoneVerified) {
      showError("Please verify your phone number");
      return;
    }

    setState(() => loading = true);

    try {
      final Map<String, dynamic> body = {
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "password": passwordController.text.trim(),
        "role": widget.role,
      };

      if (widget.showVolunteerFields) {
        body.addAll({
          "contact_number": contactController.text.trim().isEmpty
              ? null
              : contactController.text.trim(),
          "city": cityController.text.trim().isEmpty
              ? null
              : cityController.text.trim(),
        });
      }

      if (widget.showOrganiserFields) {
        body.addAll({
          "contact_number": contactController.text.trim(),
          "government_id": govIdController.text.trim().isEmpty
              ? null
              : govIdController.text.trim(),
        });
      }

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        String msg = "Registration failed";
        try {
          final data = jsonDecode(response.body);
          msg = data["message"] ?? msg;
        } catch (_) {
          msg = response.body;
        }
        showError(msg);
      }
    } catch (e) {
      showError("Network error. Please try again.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showError(String msg) {
    setState(() => errorMessage = msg);
  }

  Future<void> sendEmailOtp() async {
    if (emailController.text.trim().isEmpty) {
      showError("Email is required");
      return;
    }

    setState(() {
      sendingOtp = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/request-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": emailController.text.trim(),
          "channel": "email",
        }),
      );

      if (response.statusCode == 200) {
        setState(() => emailOtpSent = true);
      } else {
        final data = jsonDecode(response.body);
        showError(data["message"] ?? "Failed to send OTP");
      }
    } catch (_) {
      showError("Failed to send OTP");
    } finally {
      if (mounted) setState(() => sendingOtp = false);
    }
  }

  Future<void> verifyEmailOtp() async {
    if (emailOtpController.text.trim().isEmpty) {
      showError("Enter the OTP sent to your email");
      return;
    }

    setState(() {
      verifyingOtp = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/auth/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": emailController.text.trim(),
          "channel": "email",
          "otp": emailOtpController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        setState(() => emailVerified = true);
      } else {
        final data = jsonDecode(response.body);
        showError(data["message"] ?? "OTP verification failed");
      }
    } catch (_) {
      showError("OTP verification failed");
    } finally {
      if (mounted) setState(() => verifyingOtp = false);
    }
  }

  Future<void> sendPhoneOtp() async {
    final phone = contactController.text.trim();
    if (phone.isEmpty) {
      showError("Phone number is required");
      return;
    }

    setState(() {
      sendingPhoneOtp = true;
      errorMessage = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            setState(() {
              phoneVerified = true;
              sendingPhoneOtp = false;
            });
          }
          await FirebaseAuth.instance.signOut();
        } catch (e) {
          if (mounted) {
            setState(() => sendingPhoneOtp = false);
          }
          showError("Phone verification failed");
        }
      },
      verificationFailed: (e) {
        if (mounted) {
          setState(() => sendingPhoneOtp = false);
        }
        showError(e.message ?? "Phone verification failed");
      },
      codeSent: (verificationId, _) {
        if (mounted) {
          setState(() {
            phoneVerificationId = verificationId;
            phoneOtpSent = true;
            sendingPhoneOtp = false;
          });
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (mounted) {
          setState(() {
            phoneVerificationId = verificationId;
            sendingPhoneOtp = false;
          });
        }
      },
    );
  }

  Future<void> verifyPhoneOtp() async {
    final otp = phoneOtpController.text.trim();
    if (otp.isEmpty || phoneVerificationId == null) {
      showError("Enter the OTP sent to your phone");
      return;
    }

    setState(() {
      verifyingPhoneOtp = true;
      errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: phoneVerificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        setState(() => phoneVerified = true);
      }

      await FirebaseAuth.instance.signOut();
    } catch (_) {
      showError("Phone OTP verification failed");
    } finally {
      if (mounted) setState(() => verifyingPhoneOtp = false);
    }
  }

  Widget _phoneOtpSection() {
    if (!enablePhoneOtp || contactController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: sendingPhoneOtp ? null : sendPhoneOtp,
                child: Text(
                  sendingPhoneOtp ? "Sending..." : "Send Phone OTP",
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (phoneVerified)
              const Icon(Icons.verified, color: Colors.green),
          ],
        ),
        if (phoneOtpSent) ...[
          const SizedBox(height: 12),
          inputField(
            icon: Icons.lock_outline,
            hint: "Enter phone OTP",
            controller: phoneOtpController,
          ),
          ElevatedButton(
            onPressed: verifyingPhoneOtp ? null : verifyPhoneOtp,
            child: Text(
              verifyingPhoneOtp ? "Verifying..." : "Verify Phone OTP",
            ),
          ),
        ],
      ],
    );
  }

  Widget inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    bool? isObscured,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          suffixIcon: onToggleObscure == null
              ? null
              : IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    (isObscured ?? true)
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.role == "organiser"
                        ? "Organiser Registration"
                        : "Volunteer Registration",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  inputField(
                    icon: Icons.person,
                    hint: "Name",
                    controller: nameController,
                  ),
                  inputField(
                    icon: Icons.email,
                    hint: "Email",
                    controller: emailController,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: sendingOtp ? null : sendEmailOtp,
                          child: Text(
                            sendingOtp ? "Sending..." : "Send Email OTP",
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (emailVerified)
                        const Icon(Icons.verified, color: Colors.green),
                    ],
                  ),
                  if (emailOtpSent) ...[
                    const SizedBox(height: 12),
                    inputField(
                      icon: Icons.lock_outline,
                      hint: "Enter OTP",
                      controller: emailOtpController,
                    ),
                    ElevatedButton(
                      onPressed: verifyingOtp ? null : verifyEmailOtp,
                      child: Text(
                        verifyingOtp ? "Verifying..." : "Verify OTP",
                      ),
                    ),
                  ],
                  inputField(
                    icon: Icons.lock,
                    hint: "Password",
                    controller: passwordController,
                    obscure: _obscurePassword,
                    isObscured: _obscurePassword,
                    onToggleObscure: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),

                  if (widget.showVolunteerFields) ...[
                    inputField(
                      icon: Icons.phone,
                      hint: "Contact number (optional)",
                      controller: contactController,
                    ),
                    _phoneOtpSection(),
                    inputField(
                      icon: Icons.location_city,
                      hint: "City (optional)",
                      controller: cityController,
                    ),
                  ],

                  if (widget.showOrganiserFields) ...[
                    inputField(
                      icon: Icons.phone,
                      hint: "Contact number",
                      controller: contactController,
                    ),
                    _phoneOtpSection(),
                    inputField(
                      icon: Icons.badge,
                      hint: "Government ID (optional)",
                      controller: govIdController,
                    ),
                  ],

                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),

                  const SizedBox(height: 20),

                  loading
                      ? const CircularProgressIndicator()
                      : AbsorbPointer(
                          absorbing: loading,
                          child: Opacity(
                            opacity: loading ? 0.6 : 1,
                            child: GradientButton(
                              text: "Register",
                              onTap: register,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
