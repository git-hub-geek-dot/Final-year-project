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
  bool loading = false;
  String? message;
  int _cooldown = 0;
  static const int _cooldownSeconds = 30;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _cooldownSeconds);
    Future.doWhile(() async {
      if (!mounted) return false;
      if (_cooldown <= 0) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldown--);
      return _cooldown > 0;
    });
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
        setState(() => message =
            "If the email exists, a reset token has been sent.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reset email sent")),
        );
        _startCooldown();
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
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
                  const Text(
                    "Reset your password",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Enter your email to receive a reset token.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _inputField(
                    icon: Icons.email,
                    hint: "Email",
                    controller: emailController,
                  ),
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
                  (loading || _cooldown > 0)
                      ? const CircularProgressIndicator()
                      : AbsorbPointer(
                          absorbing: loading || _cooldown > 0,
                          child: Opacity(
                            opacity: (loading || _cooldown > 0) ? 0.6 : 1,
                            child: GradientButton(
                              text: _cooldown > 0
                                  ? "Resend in ${_cooldown}s"
                                  : "Send Reset Email",
                              onTap: sendResetEmail,
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () =>
                            Navigator.pushNamed(context, "/reset-password"),
                    child: const Text("Already have a token? Reset now"),
                  ),
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
