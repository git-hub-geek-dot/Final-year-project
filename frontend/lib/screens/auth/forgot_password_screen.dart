import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  String? message;
  bool _otpSent = false; // Track if OTP has been sent

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (email.isEmpty || otp.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => message = "All fields are required");
      return;
    }

    if (password != confirm) {
      setState(() => message = "Passwords do not match");
      return;
    }

    if (password.length < 6) {
      setState(() => message = "Password must be at least 6 characters");
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "otp": otp,
          "password": password,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset successful")),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      } else {
        final data = jsonDecode(response.body);
        setState(() => message = data["message"] ?? "Reset failed");
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = "Network error. Please try again.");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendResetEmail() async {
    if (emailController.text.trim().isEmpty) {
      setState(() => message = "Email is required");
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          message = "If the email exists, a reset OTP has been sent.";
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reset email sent")),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() => message = data["message"] ?? "Request failed");
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = "Network error. Please try again.");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
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
      appBar: AppBar(title: const Text("Forgot Password")),
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
                    _otpSent ? "Set a new password" : "Reset your password",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _otpSent
                        ? "Enter the OTP from your email and set a new password."
                        : "Enter your email to receive a reset OTP.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _inputField(
                    icon: Icons.email,
                    hint: "Email",
                    controller: emailController,
                  ),
                  if (_otpSent) ...[
                    _inputField(
                      icon: Icons.confirmation_number,
                      hint: "Reset OTP",
                      controller: otpController,
                    ),
                    _inputField(
                      icon: Icons.lock,
                      hint: "New Password",
                      controller: passwordController,
                      obscure: true,
                    ),
                    _inputField(
                      icon: Icons.lock_outline,
                      hint: "Confirm Password",
                      controller: confirmController,
                      obscure: true,
                    ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: message!.toLowerCase().contains("sent")
                              ? Colors.green
                              : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  loading
                      ? const CircularProgressIndicator()
                      : AbsorbPointer(
                          absorbing: loading,
                          child: Opacity(
                            opacity: loading ? 0.6 : 1,
                            child: GradientButton(
                              text: _otpSent ? "Reset Password" : "Send Reset OTP",
                              onTap: _otpSent ? resetPassword : sendResetEmail,
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  if (_otpSent) ...[
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                _otpSent = false;
                                otpController.clear();
                                passwordController.clear();
                                confirmController.clear();
                                message = null;
                              });
                            },
                      child: const Text("Change Email"),
                    ),
                  ],
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.pushNamed(context, "/"),
                    child: const Text("Back to login"),
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
